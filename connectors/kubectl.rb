# frozen_string_literal: true

require 'kubeclient'

class KubernetesNotConnectedError < StandardError
end

# Class to handle all interactions with k8
class KubeCtl
  include Kubeclient::ClientMixin

  def initialize(url = 'https://kubernetes.default.svc', version = 'v1', auth_options: nil, ssl_options: nil)
    @logger = Logging.logger[self]
    @logger.info "Initializing connection to #{url}..."
    secrets_dir = File.join(
      ENV.fetch('TELEPRESENCE_ROOT', ''),
      '/var/run/secrets/kubernetes.io/serviceaccount/'
    )
    auth_options ||= { bearer_token_file: File.join(secrets_dir, 'token') }
    @logger.debug { "auth_options -> #{auth_options}" }
    ssl_options ||= { ca_file: File.join(secrets_dir, 'ca.crt') }
    @logger.debug { "ssl_options -> #{ssl_options}" }

    initialize_client(url, '/api', version, auth_options: auth_options, ssl_options: ssl_options)

    @logger.info "Connection to #{url} established."
  end
end
