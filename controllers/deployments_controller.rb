# frozen_string_literal: true

require 'json'

require 'application_controller'

# Controller to handle displaying apps
class DeploymentsController < ApplicationController
  get '/:namespace/:name' do
    param :namespace, String, required: true
    param :name, String, required: true

    ns = params[:namespace]
    name = params[:name]
    k8_url = Settings&.kubernetes&.url
    auth_options = Settings&.kubernetes&.auth_options&.to_h
    ssl_options = Settings&.kubernetes&.ssl_options&.to_h

    v1 = KubeCtl.new(
      k8_url,
      'v1',
      auth_options: auth_options,
      ssl_options: ssl_options
    )
    k8 = KubeCtl.new(
      URI.join(k8_url, '/apis/extensions'),
      'v1beta1',
      auth_options: auth_options,
      ssl_options: ssl_options
    )

    @deployment = k8.get_deployment(name, ns)

    @stats = {
      DesiredReplicas: @deployment.spec.replicas,
      ReadyReplicas: @deployment.status.readyReplicas
    }

    # If we have a selector, let's look at any running pods that match
    label_selector = []
    @deployment.spec&.selector&.matchLabels&.each_pair do |label, value|
      label_selector << "#{label}=#{value}"
    end
    @pods = v1.get_pods(namespace: ns, label_selector: label_selector.join(','))

    # Last but not least, let's make some crumbs
    @crumbs = {
      'Namespaces' => '',
      @deployment.metadata.namespace => link_for(:namespace, @deployment.metadata.namespace),
      @deployment.metadata.name => ''
    }

    heading "Deployment: #{@deployment.metadata.name || 'Unknown'}"

    slim :deployment
  end
end
