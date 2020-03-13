# frozen_string_literal: true

require 'benchmark'
require 'daybreak'
require 'kubeclient'
require 'logger'
require 'prometheus/api_client'

require 'bms'
require 'bms/result'

module BMS
  # Class for BMS::Worker to run infinite loop gathering data.
  class Worker
    attr_reader :last_result

    def initialize
      @log = Logger.new(STDOUT)
      @log.info 'Starting initialization.'
      # Init variables
      @last_result = nil
      # Init Connections
      @db = Daybreak::DB.new '/tmp/bms.db'
      # Start the main loop
      begin
        @db[:runs] = [] unless @db[:runs].is_a? Array
        init_kubernetes
        init_prometheus
        loop do # TODO: Add some error handling here
          begin
            @log.info 'Refreshing result data.'
            elapsed = Benchmark.measure { @last_result = refresh }
            @log.info "Completed refresh in #{elapsed.real.round(2)} seconds."
          rescue StandardError => e
            @log.error "Error trying to run data refresh: #{e}"
            raise if Settings.env == 'development'
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
      q = ->(query) { @prom.query(query: query) }
      single_value = ->(query) { q[query]['result'].first['value'].last }
      multi_value = ->(query, name) { q[query]['result'].map { |x| { name: x['metric'][name.to_s], value: x['value'].last } } }
      # fields_query = ->(query, fields) { q[query]['result'].map { |x| x['metric'].slice(*fields.map(&:to_s)) } }
      # enum_query = ->(query, values) { values.map { |v| { name: v, value: single_value[query % { value: v }] } } }

      # Get nodes
      nodes = @kubectl.get_nodes selector: '!node-role.kubernetes.io/master'

      ###
      # Kubernetes Node Information
      ###

      cpu_saturation = lambda do |n|
        rtn = single_value[%[sum(kube_pod_container_resource_requests_cpu_cores{node="#{n}"})/sum(kube_node_status_allocatable_cpu_cores{node="#{n}"})]]
        return rtn.to_f * 100
      end

      cpu_utilization = lambda do |n|
        cpu_alloc = @kubectl.get_node(n)[:status][:allocatable][:cpu]
        cpu_used  = @kubectl_metrics.get_entity('nodes', n)[:usage][:cpu]
        (BMS.convert_cores(cpu_used) / BMS.convert_cores(cpu_alloc)) * 100
      end

      mem_saturation = lambda do |n|
        rtn = single_value[%[sum(kube_pod_container_resource_requests_memory_bytes{node="#{n}"}) / sum(kube_node_status_allocatable_memory_bytes{node="#{n}"})]]
        rtn.to_f * 100
      end

      ram_utilization = lambda do |n|
        ram_alloc = @kubectl.get_node(n)[:status][:allocatable][:memory]
        ram_used = @kubectl_metrics.get_entity('nodes', n)[:usage][:memory]
        (BMS.convert_ram(ram_used) / BMS.convert_ram(ram_alloc)) * 100
      end

      results[:nodes] = nodes.map do |node|
        name = node[:metadata][:name]
        conditions = node[:status][:conditions].select do |condition|
          condition[:status] == 'True'
        end
        conditions.map! { |condition| condition[:type] }
        {
          name: name,
          conditions: conditions,
          cpu_allocation_percent: cpu_saturation[name],
          ram_allocation_percent: mem_saturation[name],
          cpu_utilization_percent: cpu_utilization[name],
          ram_utilization_percent: ram_utilization[name]
        }
      end

      ###
      # Kubernetes Pod Info
      ###

      results[:unhealthy_pods] = @kubectl.get_pods(
        field_selector: 'status.phase!=Running,status.phase!=Succeeded'
      ).map do |p|
        {
          name: p[:metadata][:name],
          namespace: p[:metadata][:namespace],
          status: p[:status][:phase]
        }
      end

      # Pods that have restarted in the past 24h
      qry = 'floor(delta(kube_pod_container_status_restarts_total[24h])) > 0'
      results[:pod_restarts] = multi_value[qry, :pod]

      # Nodes with high load (5m?)
      # Deployments with mismatching requested v ready

      results[:uris] = []
      Settings.uris.each do |name, values|
        case values
        when Config::Options
          values = values.to_h
        when Hash
          nil
        when String
          values = { uri: values }
        else
          @log.warn "Failed to parse URI. values.class == #{values.class}"
          next
        end
        values.default = {} # This helps us with nested lookup key errors
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
                            msg = values[:response_codes][resp.code.to_sym] ||
                                  resp.message
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
      end
      results[:timestamp] = Time.now.to_i
      # Done grabbing results
      @db.lock do
        @log.debug { "Current @db[:runs] = #{@db[:runs]}" }
        @db[:runs] = @db[:runs].append(results[:timestamp])
        @log.debug { "After addition @db[:runs] = #{@db[:runs]}" }
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
      k8_uri = 'https://kubernetes.default.svc'
      secrets_dir = File.join(
        ENV.fetch('TELEPRESENCE_ROOT', ''),
        '/var/run/secrets/kubernetes.io/serviceaccount/'
      )
      auth_options = {
        bearer_token_file: File.join(secrets_dir, 'token')
      }
      ssl_options = {
        ca_file: File.join(secrets_dir, 'ca.crt')
      }
      @kubectl = Kubeclient::Client.new(
        k8_uri,
        'v1',
        auth_options: auth_options,
        ssl_options: ssl_options
      )
      @kubectl_metrics = Kubeclient::Client.new(
        "#{k8_uri}/apis/metrics.k8s.io",
        'v1beta1',
        auth_options: auth_options,
        ssl_options: ssl_options
      )
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
      begin
        http = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        http.get(uri.path)
      rescue Net::HTTPRequestTimeOut
        Net::HTTPResponse.new('', 408, 'TIMEDOUT')
      rescue SocketError
        Net::HTTPResponse.new('', 400, 'CONNECTION FAILED')
      end
    end
    # BMS::Worker
  end
  # BMS
end
