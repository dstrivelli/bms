# frozen_string_literal: true

require 'json'
require 'uri'

require 'application_controller'

# Controller to handle health reports
class NamespaceController < ApplicationController
  get '/:name' do
    param :name, String, required: true

    ns = params[:name]
    k8_url = Settings&.kubernetes&.url
    auth_options = Settings&.kubernetes&.auth_options&.to_h
    ssl_options = Settings&.kubernetes&.ssl_options&.to_h

    corev1 = KubeCtl.new(
      k8_url,
      auth_options: auth_options,
      ssl_options: ssl_options
    )
    appsv1 = KubeCtl.new(
      URI.join(k8_url, '/apis/apps'),
      'v1',
      auth_options: auth_options,
      ssl_options: ssl_options
    )
    extensionsv1beta1 = KubeCtl.new(
      URI.join(k8_url, '/apis/extensions'),
      'v1beta1',
      auth_options: auth_options,
      ssl_options: ssl_options
    )

    concurrent = false
    if concurrent
      require 'typhoeus'
      # Since most of the url building is usually handled by KubeClient, we
      # have to do it manually if we want concurrency.
      options = {
        connecttimeout: 30,
        maxredirs: 5,
        cainfo: ssl_options[:ca_file],
        ssl_verifypeer: ssl_options[:verify_ssl],
        sslcert: ssl_options[:client_cert],
        sslkey: ssl_options[:client_key],
        headers: { Accept: 'application/json' }
      }
      options[:userpwd] = "#{auth_options[:username]}:#{auth_options[:password]}" unless auth_options[:username].nil? && auth_options[:password].nil?
      # Handle ssl client cert/key
      cleanup_files = []
      # cURL expects our client cert to be in a file
      if options[:sslcert].is_a? OpenSSL::X509::Certificate
        crtfile = Tempfile.new('bms')
        cleanup_files << crtfile
        begin
          crtfile.write(options[:sslcert].to_pem)
          options[:sslcert] = crtfile.path
        ensure
          crtfile.close
        end
      end
      if options[:sslkey].is_a? OpenSSL::PKey::RSA
        keyfile = Tempfile.new('bms')
        cleanup_files << keyfile
        begin
          keyfile.write(options[:sslkey].to_pem)
          options[:sslkey] = keyfile.path
        ensure
          keyfile.close
        end
      end

      ns_prefix = "namespaces/#{ns}"
      hydra = Typhoeus::Hydra.hydra

      namespace_req = Typhoeus::Request.new(
        URI.join(k8_url, "/api/v1/namespaces/#{ns}"),
        options
      )
      hydra.queue namespace_req
      daemonsets_req = Typhoeus::Request.new(
        URI.join(k8_url, "/apis/extensions/v1beta1/#{ns_prefix}/daemonsets"),
        options
      )
      hydra.queue daemonsets_req
      deployments_req = Typhoeus::Request.new(
        URI.join(k8_url, "/apis/extensions/v1beta1/#{ns_prefix}/deployments"),
        options
      )
      hydra.queue deployments_req
      statefulsets_req = Typhoeus::Request.new(
        URI.join(k8_url, "/apis/extensions/v1beta1/#{ns_prefix}/statefulsets"),
        options
      )
      hydra.queue statefulsets_req
      pods_req = Typhoeus::Request.new(
        URI.join(k8_url, "/api/v1/#{ns_prefix}/pods"),
        options
      )
      hydra.queue pods_req
      events_req = Typhoeus::Request.new(
        URI.join(k8_url, "/api/v1/#{ns_prefix}/events"),
        options
      )
      hydra.queue events_req

      hydra.run # Go!

      # Clean up temp files
      cleanup_files.each(&:unlink)

      # Process responses. I know this is messy but I don't have time to make
      # this better.
      @namespace = Kubeclient::Resource.new(JSON.parse(namespace_req.response.body))
      @daemonsets = extensionsv1beta1.send :format_response, :ros, daemonsets_req.response.body, 'DaemonSet'
      @deployments = extensionsv1beta1.send :format_response, :ros, deployments_req.response.body, 'Deployment'
      @statefulsets = extensionsv1beta1.send :format_response, :ros, statefulsets_req.response.body, 'StatefulSet'
      @pods = corev1.send :format_response, :ros, pods_req.response.body, 'Pod'
      @events = corev1.send :format_response, :ros, events_req.response.body, 'Event'
    else
      @namespace = corev1.get_namespace(ns)
      @configmaps = corev1.get_config_maps(namespace: ns)
      @daemonsets = extensionsv1beta1.get_daemon_sets(namespace: ns)
      @deployments = extensionsv1beta1.get_deployments(namespace: ns)
      @ingresses = extensionsv1beta1.get_ingresses(namespace: ns)
      @secrets = corev1.get_secrets(namespace: ns)
      @services = corev1.get_services(namespace: ns)
      @statefulsets = appsv1.get_stateful_sets(namespace: ns)
      @pods = corev1.get_pods(namespace: ns)
      @events = corev1.get_events(namespace: ns, 'sort-by': '.lastTimestamp')
    end

    heading "Namespace: #{@namespace&.metadata&.name || 'Unknown'}"

    @crumbs = {
      'Namespaces' => '',
      ns => ''
    }

    respond_to do |format|
      format.html { slim :namespace }
    end
  end
end
