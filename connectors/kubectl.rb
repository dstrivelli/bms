# frozen_string_literal: true

require 'kubeclient'

class KubernetesNotConnectedError < StandardError
end

# Class to handle all interactions with k8
class KubeCtl
  include Kubeclient::ClientMixin

  # Constants
  DEFAULT_URL = 'https://kubernetes.default.svc'
  APPS_URI = '/apis/apps'
  EXTENSIONS_URI = '/apis/extensions'
  METRICS_URI = '/apis/metrics.k8s.io'

  def initialize(url: DEFAULT_URL, version: 'v1', auth_options: nil, ssl_options: nil)
    @logger = Logging.logger[self]
    @logger.debug "Initializing connection to #{url}..."
    secrets_dir = File.join(
      ENV.fetch('TELEPRESENCE_ROOT', ''),
      '/var/run/secrets/kubernetes.io/serviceaccount/'
    )

    auth_options ||= { bearer_token_file: File.join(secrets_dir, 'token') }
    @logger.debug { "auth_options -> #{auth_options}" }

    ssl_options ||= { ca_file: File.join(secrets_dir, 'ca.crt') }
    # If a string was passed in from config file, we need to gen a cert/key object
    ssl_options[:client_cert] = OpenSSL::X509::Certificate.new(ssl_options[:client_cert]) if ssl_options[:client_cert].is_a? String
    ssl_options[:client_key] = OpenSSL::PKey::RSA.new(ssl_options[:client_key]) if ssl_options[:client_key].is_a? String
    @logger.debug { "ssl_options -> #{ssl_options}" }

    initialize_client(url, '/api', version, auth_options: auth_options, ssl_options: ssl_options)
  end

  def self.apps(url: DEFAULT_URL, version: 'v1', auth_options: nil, ssl_options: nil)
    url = URI.join(url, APPS_URI)
    KubeCtl.new(url: url, version: version, auth_options: auth_options, ssl_options: ssl_options)
  end

  def self.core(url: DEFAULT_URL, version: 'v1', auth_options: nil, ssl_options: nil)
    KubeCtl.new(url: url, version: version, auth_options: auth_options, ssl_options: ssl_options)
  end

  def self.extensions(url: DEFAULT_URL, version: 'v1beta1', auth_options: nil, ssl_options: nil)
    url = URI.join(url, EXTENSIONS_URI)
    KubeCtl.new(url: url, version: version, auth_options: auth_options, ssl_options: ssl_options)
  end

  def self.metrics(url: DEFAULT_URL, version: 'v1beta1', auth_options: nil, ssl_options: nil)
    url = URI.join(url, METRICS_URI)
    KubeCtl.new(url: url, version: version, auth_options: auth_options, ssl_options: ssl_options)
  end
end
