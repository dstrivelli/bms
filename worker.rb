#!/usr/bin/env ruby
# frozen_string_literal: true

# Add lib dir to path
$LOAD_PATH << File.join(__dir__, 'lib')
$stdout.sync = true

require 'config'
require 'fileutils'
require 'logging'
require 'uri'

# Load all our application requirements
%w[connectors models].each do |dir|
  # $LOAD_PATH.unshift(File.expand_path(dir, __dir__))
  Dir.glob("./#{dir}/**/*.rb").sort.each { |file| require file }
end

# Try to load Pry if it's available
begin
  require 'pry'
rescue LoadError
  nil
end

# Configure settings (can only be done once)
Config.setup do |config|
  config.use_env = true
  config.env_prefix = 'BMS'
  config.env_separator = '__'
end
env = ENV.fetch('APP_ENV', 'development')

def load_settings(env)
  Config.load_and_set_settings(
    Config.setting_files(File.join(__dir__, 'config'), env)
  )
  Settings.env = env
end

load_settings(env)

pid_file = Settings&.worker&.pid_file || '/tmp/bms_worker.pid'
if File.exist? pid_file
  puts 'Only one instance of worker can run at a time.'
  puts 'If this in error, remove ' + pid_file
  exit 1
else
  File.open(pid_file, 'w') { |f| f.write Process.pid }
end

# Setup database
redis_host = Settings&.redis || 'redis://127.0.0.1:6379'
Ohm.redis = Redic.new(redis_host)

# CONSTANTS
CPU_ORDERS_OF_MAGNITUDE = {
  m: 1000,
  n: 1_000_000_000
}.freeze

RAM_ORDERS_OF_MAGNITUDE = {
  Ki: 1000,
  Mi: 1_000_000
}.freeze

def convert_mcores(mcores, precision: 2)
  unit = mcores[-1].to_sym
  count = mcores[0..-2].to_f
  result = if CPU_ORDERS_OF_MAGNITUDE[unit]
             count / CPU_ORDERS_OF_MAGNITUDE[unit]
           else
             count
           end
  result.round(precision)
end

def convert_ram(ram, precision: 2)
  unit = ram[-2].to_sym
  count = ram[0..-3].to_f
  result = RAM_ORDERS_OF_MAGNITUDE.keys.include?(unit) ? count / RAM_ORDERS_OF_MAGNITUDE[unit] : count
  result.round(precision)
end

def fetch_uri(uri)
  # Get HTTP response from URI
  uri = URI(uri)
  begin
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    headers = Settings&.url_options&.headers || nil
    http.get(uri.path, headers)
  rescue Net::HTTPRequestTimeOut
    Net::HTTPResponse.new('', 408, 'TIMEDOUT')
  rescue SocketError
    Net::HTTPResponse.new('', 400, 'CONNECTION FAILED')
  end
end

def refresh_labels(repo_name)
  if (last_run = Ohm.redis.call('GET', "#{repo_name}-refreshed"))
    elapsed = Time.now.to_i - last_run.to_i
    if elapsed < (60 * 60 * 12)
      @logger.debug "Skipping update of labels for #{repo_name}... (last ran #{elapsed} seconds ago)"
      return
    end
  end
  @logger.debug "Updating Nexus Repo (#{repo_name})"
  repo = NexusRepo.new(repo_name)
  repo.images.each do |image|
    # Find the image or create one
    docker_image = DockerImage.find(repo: repo_name, name: image).first || DockerImage.create(repo: repo_name, name: image)
    # Iterate through the image tags
    repo.tags(image: image).each do |tag|
      # Find the tag or create one
      unless DockerTag.find(image_id: docker_image.id, name: tag).first
        labels = repo.labels(image: image, tag: tag)
        DockerTag.create(image: docker_image, name: tag, labels: labels)
      end
    end
  end
  Ohm.redis.call 'SET', "#{repo_name}-refreshed", Time.now.to_i.to_s
end

@logger = Logging::Logger.new('Worker')

# Configure logging
Logging.logger.root.appenders = Logging.appenders.stdout # (layout: Logging.layouts.basic)

# Helper funcs
def to_percentage(num, precision: 2)
  (num.to_f * 100).round(precision)
end

def deep_to_h(obj)
  obj = obj.to_h if obj.is_a? Config::Options
  obj.each do |k, v|
    obj[k] = deep_to_h(v) if v.is_a?(Config::Options) || v.is_a?(Hash)
  end
end

def setup_connections
  kubectl = KubeCtl.new(
    Settings&.kubernetes&.url,
    auth_options: Settings&.kubernetes&.auth_options&.to_h,
    ssl_options: Settings&.kubernetes&.ssl_options&.to_h
  )
  metrics = KubeCtl.new(
    URI.join(Settings&.kubernetes&.url, '/apis/metrics.k8s.io'),
    'v1beta1',
    auth_options: Settings&.kubernetes&.auth_options&.to_h,
    ssl_options: Settings&.kubernetes&.ssl_options&.to_h
  )
  prom = Prom.new(deep_to_h(Settings&.prometheus))
  [kubectl, metrics, prom]
end

kubectl, metrics, prom = setup_connections

begin
  report = nil # Define outside loop so we can access in rescue/ensure block
  # Start loop
  loop do
    # Initialize logging
    Logging.logger.root.level = Settings&.log_level || :warn
    # Example of how to fine tune logging:
    # Logging.logger['Prom'].level = :debug

    @logger.debug 'Starting new refresh.'
    report = Report.create(timestamp: Time.now.to_i)

    # TODO: Figure out how to run the prom queries in batches instead of each
    # Kubernetes Nodes
    kubectl.get_nodes.map do |elem|
      name = elem[:metadata][:name]
      @logger.debug "Getting info for node: #{name}"

      node = Node.new(report: report, hostname: name)

      # conditions
      conditions = elem[:status][:conditions].select { |c| c[:status] == 'True' }
      node.conditions = conditions.map! { |c| c[:type] }.join(', ')

      # cpu_allocation
      qry_string = %[sum(kube_pod_container_resource_requests_cpu_cores{node="#{name}"})/sum(kube_node_status_allocatable_cpu_cores{node="#{name}"})]
      node.cpu_allocation_percent = to_percentage(prom.single_value(qry_string))

      # ram_allocation
      qry_string = %[sum(kube_pod_container_resource_requests_memory_bytes{node="#{name}"}) / sum(kube_node_status_allocatable_memory_bytes{node="#{name}"})]
      node.ram_allocation_percent = to_percentage(prom.single_value(qry_string))

      # cpu_utilization
      cpu_alloc = kubectl.get_node(name)[:status][:allocatable][:cpu]
      cpu_used  = metrics.get_entity('nodes', name)[:usage][:cpu]
      node.cpu_utilization_percent = to_percentage(convert_mcores(cpu_used) / convert_mcores(cpu_alloc))

      # ram_utilization
      ram_alloc = kubectl.get_node(name)[:status][:allocatable][:memory]
      ram_used = metrics.get_entity('nodes', name)[:usage][:memory]
      node.ram_utilization_percent = to_percentage(convert_ram(ram_used) / convert_ram(ram_alloc))

      node.save
    end

    # Pods in an "unhealthy" state
    kubectl.get_pods(
      field_selector: 'status.phase!=Running,status.phase!=Succeeded'
    ).map do |pod|
      UnhealthyPod.create(
        report: report,
        pod: pod[:metadata][:name],
        namespace: pod[:metadata][:namespace],
        state: pod[:status][:phase]
      )
    end

    # Pods that have restarted in the past 24h
    qry = 'floor(delta(kube_pod_container_status_restarts_total[24h])) > 0'
    prom.multi_value(qry, %i[namespace pod]).each do |pod|
      Restart.create(
        report: report,
        namespace: pod[:namespace],
        pod: pod[:pod],
        count: pod[:value]
      )
    end

    # Health Checks
    Settings.uris.each do |name, values|
      case values
      when Config::Options
        values = values.to_h
      when Hash
        nil
      when String
        values = { uri: values }
      else
        @logger.warn "Failed to parse URI. values.class == #{values.class}"
        next
      end
      values.default = {} # This helps us with nested lookup key errors
      @logger.debug "Fetching #{values[:uri]}..."
      resp = fetch_uri values[:uri]
      @logger.debug "Response code: #{resp.code} #{resp.message}"
      result = case values.fetch(:type, :response_code).to_sym
               when :json
                 json = JSON.parse(resp.body)
                 {
                   name: name.to_s,
                   uri: values[:uri],
                   result: json[values[:value]]
                 }
               when :response_code
                 msg = values[:response_codes][resp.code.to_s.to_sym] || resp.message
                 {
                   name: name.to_s,
                   uri: values[:uri],
                   result: "#{resp.code} #{msg}"
                 }
               else
                 {
                   name: name.to_s,
                   uri: values[:uri],
                   result: 'ERROR: Invalid result_type.'
                 }
               end
      HealthCheck.create({ report: report }.merge(result))
    end

    report.update(complete: true)
    report = nil # Unset finalized report so ensure block doesn't delete

    # Update docker labels
    Settings&.nexus&.repos&.keys&.each { |repo| refresh_labels(repo) }

    sleep_for = Settings&.worker&.sleep || 300
    @logger.debug "Sleeping for #{sleep_for} seconds..."
    sleep(sleep_for.to_i)
  end # loop
rescue Interrupt
  puts 'INTERRUPTED'
rescue SignalException => e
  if e.signm == 'SIGHUP'
    @logger.info 'Reloading config and restarting worker...'
    load_settings(env)
    kubectl, metrics, prom = setup_connections
    retry
  end
  raise
ensure
  report.delete if defined?(report) && report # Delete incomplete report
  FileUtils.rm(pid_file, force: true) # Clean up pid file
end
