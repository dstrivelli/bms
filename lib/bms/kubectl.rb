# frozen_string_literal: true

require 'kubeclient'
require 'singleton'

module BMS
  class KubernetesNotConnectedError < StandardError
  end

  # Class to handle all interactions with k8
  class KubeCtl
    include Singleton

    @kubectl = nil
    @kubectl_metrics = nil
    @logger = Logging.logger[self]

    attr_reader :kubectl, :kubectl_metrics

    def self.connect(url = 'https://kubernetes.default.svc')
      @logger.info "Initializing connection to #{url}..."
      secrets_dir = File.join(
        ENV.fetch('TELEPRESENCE_ROOT', ''),
        '/var/run/secrets/kubernetes.io/serviceaccount/'
      )
      auth_options = {
        bearer_token_file: File.join(secrets_dir, 'token')
      }
      @logger.debug { "auth_options -> #{auth_options}" }
      ssl_options = {
        ca_file: File.join(secrets_dir, 'ca.crt')
      }
      @logger.debug { "ssl_options -> #{ssl_options}" }
      @kubectl = Kubeclient::Client.new(
        url,
        'v1',
        auth_options: auth_options,
        ssl_options: ssl_options
      )
      @kubectl_metrics = Kubeclient::Client.new(
        URI.join(url, '/apis/metrics.k8s.io'),
        'v1beta1',
        auth_options: auth_options,
        ssl_options: ssl_options
      )
      @logger.info 'Connection to k8 established.'
    end

    def self.verify_connection
      raise KubernetesNotConnectedError unless @kubectl
      raise KubernetesNotConnectedError unless @kubectl_metrics
    end

    def self.kubectl
      verify_connection
      @kubectl
    end

    def self.kubectl_metrics
      verify_connection
      @kubectl_metrics
    end
  end # BMS::KubeCtl
end # BMS
