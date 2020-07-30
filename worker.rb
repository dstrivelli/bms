#!/usr/bin/env ruby
# frozen_string_literal: true

# Add lib dir to path
$LOAD_PATH << File.join(__dir__, 'lib')
$stdout.sync = true

require 'config'
require 'fileutils'
require 'logging'
require 'uri'

require_relative 'version'

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

# Setup database
redis_host = Settings&.redis || 'redis://127.0.0.1:6379'
Ohm.redis = Redic.new(redis_host)

# Flush database if the data in Redis is old
db_version = Ohm.redis.call('GET', 'version')
unless db_version == BMS::VERSION
  print 'Database version mismatch, flushing...'
  Ohm.redis.call('FLUSHALL')
  puts 'done.'
end
Ohm.redis.call('SET', 'version', BMS::VERSION)

# CONSTANTS
CPU_ORDERS_OF_MAGNITUDE = {
  m: 1000,
  n: 1000**3
}.freeze

RAM_ORDERS_OF_MAGNITUDE = {
  Ki: 1024,
  Mi: 1024**2,
  Gi: 1024**3,
  Ti: 1024**4,
  Pi: 1024**5,
  Ei: 1024**6,
  K: 1000,
  M: 1000**2,
  G: 1000**3,
  T: 1000**4,
  P: 1000**5,
  E: 1000**6
}.freeze

def convert_mcores(mcores, precision: 2)
  return 0.0 if mcores.nil?

  unit = mcores[-1].to_sym
  count = mcores[0..-2].to_f
  result = if CPU_ORDERS_OF_MAGNITUDE[unit]
             count / CPU_ORDERS_OF_MAGNITUDE[unit]
           else
             count
           end
  result.round(precision)
end

def convert_ram(ram)
  return 0 if ram.nil?

  ram_regex = /(?<count>[0-9]*)(?<unit>(#{RAM_ORDERS_OF_MAGNITUDE.keys.join('|')}))?$/
  matches = ram_regex.match(ram)
  raise "Error in #convert_ram. The value #{ram} does not match the regex." if matches.nil?

  if matches[:unit].nil?
    matches[:count].to_i
  else
    matches[:count].to_i * RAM_ORDERS_OF_MAGNITUDE[matches[:unit].to_sym]
  end
end

def fetch_uri(uri)
  # Get HTTP response from URI
  uri = URI(uri)
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https'
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  headers = Settings&.url_options&.headers || nil
  http.get(uri, headers)
rescue Net::HTTPRequestTimeOut, Net::OpenTimeout
  Net::HTTPResponse.new('', 408, 'TIMEDOUT')
rescue SocketError, Errno::ECONNREFUSED
  Net::HTTPResponse.new('', 400, 'CONNECTION FAILED')
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
Logging.logger.root.level = Settings&.log_level || :warn

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
  extensions = KubeCtl.new(
    URI.join(Settings&.kubernetes&.url, '/apis/extensions'),
    'v1beta1',
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
  [kubectl, extensions, metrics, prom]
end

kubectl, extensions, metrics, prom = setup_connections

begin
  pid_file = Settings&.worker&.pid_file || '/tmp/bms_worker.pid'
  if File.exist? pid_file
    puts 'Only one instance of worker can run at a time.'
    puts 'If this in error, remove ' + pid_file
    exit 1
  else
    File.open(pid_file, 'w') { |f| f.write Process.pid }
  end

  # Start loop
  loop do
    # Initialize logging
    Logging.logger.root.level = Settings&.log_level || :warn
    # Example of how to fine tune logging:
    # Logging.logger['Prom'].level = :debug

    @logger.info 'Starting new refresh...'

    ### Update Nodes

    nodes = kubectl.get_nodes
    metrics_hash = metrics.get_nodes.each_with_object({}) { |n, o| o[n.metadata.name] = n.to_hash }

    # TODO: Figure out how to run the prom queries in batches instead of each
    # Kubernetes Nodes
    nodes.map do |elem|
      name = elem[:metadata][:name]
      elem_metrics = metrics_hash[name]

      @logger.debug "Getting info for Node(#{name})"

      addresses = elem.status.addresses.each_with_object({}) do |a, o|
        o[a.type.downcase.to_sym] = a.address
      end
      conditions = elem[:status][:conditions].select { |c| c[:status] == 'True' }

      attrs = {
        name: name,
        hostname: addresses[:hostname],
        ip: addresses[:internalip],
        annotations: elem.metadata.annotations.to_h.stringify_keys,
        labels: elem.metadata.labels.to_h.stringify_keys,
        kernel_version: elem.status.nodeInfo.kernelVersion,
        kubelet_version: elem.status.nodeInfo.kubeletVersion,
        conditions: conditions.map! { |c| c[:type] },
        cpu_allocatable: convert_mcores(elem.status.allocatable.cpu),
        ram_allocatable: convert_ram(elem.status.allocatable.memory),
        cpu_utilized: convert_mcores(elem_metrics[:usage][:cpu]),
        ram_utilized: convert_ram(elem_metrics[:usage][:memory])
      }

      if (cached = Node.with(:name, name))
        cached.update(attrs)
      else
        Node.create(attrs)
      end
    end

    @logger.debug 'Cleaning up any extra Nodes in cache that no longer exist.'
    nodes_array = nodes.map { |elem| elem.metadata.name }
    Node.all.each do |elem|
      unless nodes_array.include? elem.name
        @logger.debug "Deleting Node(#{elem.name}) from cache"
        elem.delete
      end
    end

    ### Namespaces

    namespaces = kubectl.get_namespaces

    namespaces.each do |elem|
      @logger.debug "Getting info for Namespace(#{elem.metadata.name})"

      attrs = {
        uid: elem.metadata.uid,
        name: elem.metadata.name,
        annotations: elem.metadata&.annotations&.to_h&.stringify_keys,
        labels: elem.metadata&.labels&.to_h&.stringify_keys
      }

      if (cached = Namespace.with(:name, attrs[:name]))
        cached.update(attrs)
      else
        Namespace.create(attrs)
      end
    end

    @logger.debug 'Cleaning up any extra Namespaces in cache that no longer exist.'
    namespaces_array = namespaces.map { |elem| elem.metadata.name }
    Namespace.all.each do |elem|
      unless namespaces_array.include? elem.name
        @logger.debug "Deleting Namespace(#{elem.name}) from cache"
        elem.delete
      end
    end

    ## Deployments

    deployments = extensions.get_deployments

    deployments.each do |elem|
      @logger.debug "Getting info for Deployment(#{elem.metadata.name})"

      attrs = {
        uid: elem.metadata.uid,
        namespace_id: Namespace.with(:name, elem.metadata.namespace)&.id,
        name: elem.metadata.name,
        annotations: elem.metadata&.annotations&.to_h&.stringify_keys,
        labels: elem.metadata&.labels&.to_h&.stringify_keys,
        replicas: elem.status.replicas,
        ready_replicas: elem.status.readyReplicas,
        images: []
      }

      elem.spec.template.spec.containers.each { |c| attrs[:images] << c.image }

      if (cached = Deployment.with(:uid, attrs[:uid]))
        cached.update(attrs)
      else
        Deployment.create(attrs)
      end
    end

    @logger.debug 'Cleaning up any extra Deployments in cache that no longer exist.'
    deployments_array = deployments.map { |elem| elem.metadata.uid }
    Deployment.all.each do |elem|
      unless deployments_array.include? elem.uid
        @logger.debug "Deleting Deployment(#{elem.name}) from cache."
        elem.delete
      end
    end

    ### ReplicaSets

    @logger.debug 'Processing ReplicaSets...'

    replica_sets = extensions.get_replica_sets

    replica_sets.each do |elem|
      @logger.debug "Getting info for replicaset: #{elem.metadata.namespace}/#{elem.metadata.name}."

      attrs = {
        uid: elem.metadata.uid,
        name: elem.metadata.name,
        namespace_id: Namespace.with(:name, elem.metadata.namespace)&.id,
        deployment_id: Deployment.with(:uid, elem.metadata&.ownerReferences&.first&.uid)&.id
      }

      if (cached = ReplicaSet.with(:uid, attrs[:uid]))
        cached.update(attrs)
      else
        ReplicaSet.create(attrs)
      end
    end

    ### Pods

    pods = kubectl.get_pods

    pods.each do |elem|
      @logger.debug "Getting info for pod: #{elem.metadata.namespace}/#{elem.metadata.name}."

      attrs = {
        uid: elem.metadata.uid,
        name: elem.metadata.name,
        created_at: elem.metadata.creationTimestamp,
        namespace_id: Namespace.with(:name, elem.metadata.namespace)&.id,
        deployment_id: ReplicaSet.with(:uid, elem.metadata&.ownerReferences&.first&.uid)&.deployment&.id,
        node_id: Node.with(:name, elem.spec.nodeName).id,
        annotations: elem.metadata&.annotations&.to_h&.stringify_keys,
        labels: elem.metadata&.labels&.to_h&.stringify_keys,
        state: elem.status.phase
      }

      # Process "conditions"
      elem[:status][:conditions].each do |condition|
        condition = condition.to_h
        case condition[:type]
        when 'PodScheduled'
          attrs[:scheduled] = condition[:status] == 'True'
          attrs[:scheduled_at] = condition[:lastTransitionTime]
          attrs[:scheduled_message] = condition.key?(:message) ? condition[:message] : ''
        when 'Initialized'
          attrs[:initialized] = condition[:status] == 'True'
          attrs[:initialized_at] = condition[:lastTransitionTime]
          attrs[:initialized_message] = condition.key?(:message) ? condition[:message] : ''
        when 'Ready'
          attrs[:ready] = condition[:status] == 'True'
          attrs[:ready_at] = condition[:lastTransitionTime]
          attrs[:ready_message] = condition.key?(:message) ? condition[:message] : ''
        when 'ContainersReady'
          attrs[:containers_ready] = condition[:status] == 'True'
          attrs[:containers_ready_at] = condition[:lastTransitionTime]
          attrs[:containers_ready_message] = condition.key?(:message) ? condition[:message] : ''
        end
      end

      # Parse container_statuses
      attrs[:restarts] = 0
      ready = 0
      total = 0
      elem[:status][:containerStatuses].each do |status|
        attrs[:restarts] += status[:restartCount]
        total += 1
        ready += 1 if status.ready
      end
      attrs[:ready_string] = "#{ready}/#{total}"

      if (pod = Pod.with(:uid, attrs[:uid]))
        pod.update(attrs)
      else
        pod = Pod.create(attrs)
      end

      current_containers = pod.containers

      # enumerate containers
      elem.spec.containers.each do |container|
        attrs = {
          pod_id: pod.id,
          name: container.name,
          image: container.image,
          liveness_probe: container&.livenessProbe&.to_h&.deep_stringify_keys,
          readiness_probe: container&.readinessProbe&.to_h&.deep_stringify_keys,
          cpu_requests: convert_mcores(container&.resources&.requests&.cpu),
          ram_requests: convert_ram(container&.resources&.requests&.memory),
          cpu_limits: convert_mcores(container&.resources&.limits&.cpu),
          ram_limits: convert_ram(container&.resources&.limits&.memory)
        }

        result = current_containers.find(name: attrs[:name])
        if result.size.positive?
          result.first.update(attrs)
        else
          Container.create(attrs)
        end
        # TODO: Purge any containers that are no longer there. Do we even want them as a separate model since K8 doesn't treat them separately?
      end
    end

    # Cleanup any pods in cache that do not exist anymore
    pods_array = pods.map { |elem| elem.metadata.uid }
    Pod.all.each do |elem|
      unless pods_array.include? elem.uid
        @logger.debug "Deleting Pod(#{elem.name}) from cache."
        elem.delete
      end
    end

    # Yo, kubes, what's happened lately?
    @logger.debug 'Processing events...'
    events = kubectl.get_events

    events.each do |event|
      @logger.debug "Getting info for event: #{event.metadata[:namespace]}/#{event.metadata[:name]}"
      attrs = event.to_hash.slice(:lastTimestamp, :message, :reason)
      attrs[:uid] = event.metadata[:uid]
      attrs[:name] = event.metadata[:name]
      attrs[:kind] = event.metadata[:kind]
      # Link namespace
      attrs[:namespace_id] = Namespace.with(:name, event.metadata[:namespace]).id

      if (cached = Event.with(:uid, attrs[:uid]))
        cached.update(attrs)
      else
        cached = Event.create(attrs)
      end
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
      attrs = case values.fetch(:type, :response_code).to_sym
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
      begin
        attrs[:details] = resp.body
      rescue
        attrs[:details] = 'ERROR!'
      end
      if (cached = HealthCheck.with(:name, attrs[:name]))
        cached.update(attrs)
      else
        HealthCheck.create(attrs)
      end
    end

    @logger.debug 'Cleaning up any extra HealthChecks in cache that no longer exist.'
    healthchecks_array = Settings.uris.keys.map(&:to_s)
    HealthCheck.all.each do |elem|
      unless healthchecks_array.include? elem.name
        @logger.debug "Deleting HealthCheck(#{elem.name}) from cache"
        elem.delete
      end
    end

    # Generate report
    last_report_ran = Report.latest.first&.timestamp || 0
    if (Time.now.to_i - last_report_ran) > (Settings&.reports&.every || 0)
      timestamp = Time.now.to_i
      @logger.info "Generating new report with timestamp: #{timestamp}."
      @logger.debug 'Enumerating pods to get unhealthy ones.'
      unhealthy_pods = Pod.all.each_with_object([]) do |pod, rtn|
        if %w[Running Succeeded].include?(pod.state)
          ready, total = pod.ready_string.split('/')
          rtn << pod unless ready == total
        else
          rtn << pod
        end
      end

      Report.create(
        {
          timestamp: timestamp,
          nodes: Node.all.to_a.map(&:to_report_hash),
          restarts: prom.multi_value('floor(delta(kube_pod_container_status_restarts_total[24h])) > 0', %i[namespace pod]),
          unhealthy_pods: unhealthy_pods.map { |elem| elem.to_hash.slice(:namespace, :name, :ready_string, :restarts) },
          health_checks: HealthCheck.all.to_a.map(&:to_report_hash)
        }
      )
    end

    # Purge older reports
    @logger.debug 'Purging old reports...'
    old_reports = Ohm.redis.call('ZREVRANGEBYSCORE', 'Report:latest', Time.now.to_i - Settings.reports.purge_older_than, 0)
    old_reports.each do |id|
      report = Report[id]
      @logger.info "Purging old report: #{report.strftime}."
      report.delete
    end

    # Update docker labels
    # Settings&.nexus&.repos&.keys&.each { |repo| refresh_labels(repo) }

    sleep_for = Settings&.worker&.sleep || 300
    @logger.info "Sleeping for #{sleep_for} seconds..."
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
  FileUtils.rm(pid_file, force: true) # Clean up pid file
end
