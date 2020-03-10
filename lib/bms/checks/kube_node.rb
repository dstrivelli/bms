require 'bms/checks/check'

module BMS
  module Checks
    class KubeNode < Check
      attr_accessor :kubectl

      def initialize(args = {})
        super
        if args[:kubectl]
          @kubectl = args[:kubectl]
        else
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
      end # .initialize

      def run
        super
        # Get list of nodes
        nodes = @kubectl.get_nodes
        nodes_arr = nodes.map { |x| x[:metadata][:name] }

        # Enumerate nodes
        nodes.each do |node|
          # Gather general node info
          # Gather node resource usage (cpu, ram, pids, disk)
        end
      end # .run
    end # KubeNode
  end
end
