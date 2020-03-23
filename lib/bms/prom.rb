# frozen_string_literal: true

require 'prometheus/api_client'
require 'singleton'

module BMS
  class PrometheusNotConnectedError < StandardError
  end

  # Class to handle Promethus queries
  class Prom
    include Singleton

    @logger = Logging.logger[self]
    @prometheus = nil

    def self.connect(url)
      @logger.info "Connecting to #{url}..."
      options = {
        request: {
          timeout: 45
        }
      }
      @prometheus = Prometheus::ApiClient.client(url: url, options: options)
      @logger.info 'Connection to Prometheus estabilished.'
    end

    def self.validate_connection
      raise PrometheusNotConnectedError unless @prometheus
    end

    def self.query(query)
      validate_connection
      @logger.debug "Querying: #{query}"
      result = @prometheus.query(query: query)
      @logger.debug "Result: #{result}"
      result
    end

    def self.single_value(query)
      query(query)['result'].first['value'].last
    end

    def self.multi_value(query, name)
      query(query)['result'].map do |x|
        {
          name: x['metric'][name.to_s],
          value: x['value'].last
        }
      end
    end
  end # BMS::Prometheus
end # BMS
