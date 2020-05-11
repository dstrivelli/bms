# frozen_string_literal: true

require 'benchmark'
require 'logging'
require 'prometheus/api_client'

# It's an error. Fuck you RuboCop.
class PrometheusError < StandardError
  def initialize(msg = 'Error gathering data from Prometheus')
    super
  end
end

# Class to handle Promethus queries
class Prom
  def initialize(options = {})
    options = { request: { timeout: 45 } }.merge(options)
    @logger = Logging.logger[self]
    @logger.debug "Initializing with options: #{options}."
    @url = options[:url]
    @prom = Prometheus::ApiClient.client(options)
    @logger.debug "Connection to #{options[:url]} established."
  end

  def query(query_string)
    @logger.debug "Querying: #{query_string}"
    result = nil
    elapsed = Benchmark.measure { result = @prom.query(query: query_string) }
    @logger.debug "Result (took #{elapsed.real.round(2)} seconds): #{result}"
    result
  end

  def single_value(query)
    query(query)['result'].first['value'].last
  end

  def multi_value(query, fields)
    fields = [fields] unless fields.is_a? Array # We want an array
    query(query)['result'].map do |x|
      {}.tap do |result|
        fields.each do |f|
          result[f.to_sym] = x['metric'][f.to_s]
        end
        result[:value] = x['value'].last
      end
    end
  end
end
