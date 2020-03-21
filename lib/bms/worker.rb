# frozen_string_literal: true

require 'benchmark'
require 'kubeclient'
require 'prometheus/api_client'

require 'bms'
require 'bms/kubectl'
require 'bms/prom'

module BMS
  # Class for BMS::Worker to run infinite loop gathering data.
  class Worker
    attr_reader :last_result

    def initialize
      @logger = Logging.logger[self]
      @logger.info 'Starting initialization.'
      # Init variables
      @last_result = nil
      # Start the main loop
      begin
        # Init Connections
        KubeCtl.connect(Settings.kubernetes.url)
        Prom.connect(Settings.prometheus.url)
        loop do # TODO: Add some error handling here
          begin
            @logger.info 'Refreshing result data.'
            elapsed = Benchmark.measure do
              @last_result = refresh
              NexusRepo.repos.each do |tier|
                refresh_labels(tier, use_cache: false)
              end
            end
            @logger.info "Completed refresh in #{elapsed.real.round(2)} seconds."
          rescue StandardError => e
            @logger.error "Error trying to run data refresh: #{e}"
            raise if Settings.env == 'development'
          end
          sleep_for = Settings.worker.sleep rescue 300 # rubocop:disable Style/RescueModifier
          @logger.info("Sleeping for #{sleep_for} seconds...")
          sleep(sleep_for)
        end
      ensure
        @logger.info 'Shutting down...'
      end
    end

    def refresh
      results = Result.new

      # Get nodes
      nodes = KubeCtl.kubectl.get_nodes selector: '!node-role.kubernetes.io/master'

      ###
      # Kubernetes Node Information
      ###

      cpu_saturation = lambda do |n|
        rtn = Prom.single_value(%[sum(kube_pod_container_resource_requests_cpu_cores{node="#{n}"})/sum(kube_node_status_allocatable_cpu_cores{node="#{n}"})])
        return rtn.to_f * 100
      end

      cpu_utilization = lambda do |n|
        cpu_alloc = KubeCtl.kubectl.get_node(n)[:status][:allocatable][:cpu]
        cpu_used  = KubeCtl.kubectl_metrics.get_entity('nodes', n)[:usage][:cpu]
        (BMS.convert_cores(cpu_used) / BMS.convert_cores(cpu_alloc)) * 100
      end

      mem_saturation = lambda do |n|
        rtn = Prom.single_value(%[sum(kube_pod_container_resource_requests_memory_bytes{node="#{n}"}) / sum(kube_node_status_allocatable_memory_bytes{node="#{n}"})])
        rtn.to_f * 100
      end

      ram_utilization = lambda do |n|
        ram_alloc = KubeCtl.kubectl.get_node(n)[:status][:allocatable][:memory]
        ram_used = KubeCtl.kubectl_metrics.get_entity('nodes', n)[:usage][:memory]
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

      results[:unhealthy_pods] = KubeCtl.kubectl.get_pods(
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
      results[:pod_restarts] = Prom.multi_value(qry, :pod)

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
          @logger.warn "Failed to parse URI. values.class == #{values.class}"
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
                            msg = values[:response_codes][resp.code.to_s.to_sym] ||
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
      DB.save_result(results)
    end

    def refresh_labels(tier)
      nexus = NexusRepo.new(tier)
      result = nexus.images_with_tags
      BMS::DB.set["#{tier}-labels"] = result
    end

    private

    def fetch_uri(uri)
      # Get HTTP response from URI
      @logger.debug "fetch_uri: fetching #{uri}"
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
  end # BMS::Worker
end # BMS
