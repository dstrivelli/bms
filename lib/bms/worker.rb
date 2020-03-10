require 'benchmark'
require 'daybreak'
require 'kubeclient'
require 'logger'
require 'prometheus/api_client'

require_relative 'result'

module BMS
  class Worker
    attr_reader :last_result

    def initialize
      @log = Logger.new(STDOUT)
      @log.info 'Starting initialization.'
      # Init variables
      @last_result = nil
      # Init Connections
      @db = Daybreak::DB.new '/tmp/bms.db'
      unless @db[:runs].is_a? Array
        @db[:runs] = []
      end
      init_kubernetes
      init_prometheus
      # Start the main loop
      begin
        loop do # TODO: Add some error handling here
          begin
            @log.info 'Refreshing result data.'
            elapsed = Benchmark.measure { @last_result = self.refresh }
            @log.info "Completed refresh in #{elapsed.real.round(2)} seconds."
          rescue StandardError => msg
            @log.error "Error trying to run data refresh: #{msg}"
          end
          begin
            sleep_for = Settings.worker.sleep
          rescue KeyError
            sleep_for = 300
          end
          @log.info("Sleeping for #{sleep_for} seconds...")
          sleep(sleep_for)
        end
      ensure
        @log.info 'Shutting down...'
        @db.close
      end
    end

    def refresh
      results = Result.new

      # Setup some helper lambdas
      q = lambda { |query| @prom.query(query: query) }
      single_value = lambda { |query| q[query]['result'].first['value'].last }
      multi_value = lambda { |query, name| q[query]['result'].map { |x| { name: x['metric'][name.to_s], value: x['value'].last } } }
      fields_query = lambda { |query, fields| q[query]['result'].map { |x| x['metric'].slice(*fields.map{|y| y.to_s}) } }
      enum_query = lambda { |query, values| values.map { |v| { name: v, value: single_value[query % {value: v}]} } }

      # Get nodes
      nodes = @kubectl.get_nodes selector: '!node-role.kubernetes.io/master'
      node_arr = nodes.map { |x| x[:metadata][:name] }

      ###
      # Kubernetes Node Information
      ###

      cpu_saturation = lambda do |n|
        rtn = single_value[%Q[sum(kube_pod_container_resource_requests_cpu_cores{node="#{n}"})/sum(kube_node_status_allocatable_cpu_cores{node="#{n}"})]]
        return rtn.to_f * 100
      end

      mem_saturation = lambda do |n|
        rtn = single_value[%Q[sum(kube_pod_container_resource_requests_memory_bytes{node="#{n}"}) / sum(kube_node_status_allocatable_memory_bytes{node="#{n}"})]]
        return rtn.to_f * 100
      end

      results[:nodes] = nodes.map do |node|
        {
          name: node[:metadata][:name],
          statuses: node[:status][:conditions].select {|c| c[:status] == 'True'}.map {|x| x[:type]},
          cpu_allocation_percent: cpu_saturation[node[:metadata][:name]],
          ram_allocation_percent: mem_saturation[node[:metadata][:name]],
        }
      end

      ###
      # Kubernetes Pod Info
      ###

      results[:unhealthy_pods] = @kubectl.get_pods(field_selector: 'status.phase!=Running,status.phase!=Succeeded').map do |p|
        {
          name: p[:metadata][:name],
          namespace: p[:metadata][:namespace],
          status: p[:status][:phase],
        }
      end

      # Pods that have restarted in the past 24h
      qry = 'floor(delta(kube_pod_container_status_restarts_total[24h])) > 0'
      results[:pod_restarts] = multi_value[qry, :pod]

      # Nodes with high load (5m?)
      # Deployments with mismatching requested v ready

      results[:uris] = []
      # TODO: This part seriously needs some error handling
      Settings.uris.each do |name, values|
        case values
        when Config::Options
          values = values.to_hash
        when String
          values = { uri: values }
        else
          next
        end
        resp = fetch_uri values[:uri]
        results[:uris] << case values.fetch(:type, :response_code).to_sym
          when :json
            json = JSON.parse(resp.body)
            {
              name: name.to_s,
              uri: values[:uri],
              result: json[values[:value]]
            }
          when :response_code
            {
              name: name.to_s,
              uri: values[:uri],
              result: "#{resp.code} #{resp.message}"
            }
          else
            {
              name: name.to_s,
              uri: values[:uri],
              result: 'ERROR: Invalid result_type.'
            }
        end
      end
      results[:timestamp] = Time.now.to_i
      # Done grabbing results
      @db.lock do
        @log.debug { "Current @db[:runs] = #{@db[:runs].to_s}" }
        @db[:runs] = @db[:runs].append(results[:timestamp])
        @log.debug { "After addition @db[:runs] = #{@db[:runs].to_s}" }
        @db[results[:timestamp]] = results
        @db[:latest] = @db[results[:timestamp]]
        @db.flush
      end
      results
    end

    private

    def init_kubernetes
      # Setup connection to Kubernetes
      @log.info 'Initializing connection to Kubernetes.'
      secrets_dir = ENV['TELEPRESENCE_ROOT'].nil? ? '' : ENV['TELEPRESENCE_ROOT']
      secrets_dir = File.join(secrets_dir, '/var/run/secrets/kubernetes.io/serviceaccount/')
      auth_options = {
        bearer_token_file: File.join(secrets_dir, 'token')
      }
      ssl_options = {}
      if File.exists? File.join(secrets_dir, 'ca.crt')
        ssl_options[:ca_file] = File.join(secrets_dir, 'ca.crt')
      end
      @kubectl = Kubeclient::Client.new(
        'https://kubernetes.default.svc',
        'v1',
        auth_options: auth_options,
        ssl_options: ssl_options
      )
      #namespace = File.read File.join(secrets_dir, 'namespace')
      @log.info 'Connection to Kubernetes established.'
    end

    def init_prometheus
      # Setup connection to Prometheus
      @log.info 'Initializing connection to Prometheus.'
      @prom = Prometheus::ApiClient.client(url: Settings.prometheus.url)
      @log.info 'Connection to Prometheus established.'
    end

    def fetch_uri(uri)
      # Get HTTP response from URI
      @log.debug "fetch_uri: fetching #{uri}"
      uri = URI(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.get(uri.path)
    end
  end # #Worker
end
