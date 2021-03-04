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

    begin
      @deployment = settings.k8extensions.get_deployment(name, ns)
    rescue KubeClient::ResourceNotFoundError
      @deployment = nil
    end

    @stats = {
      DesiredReplicas: @deployment.spec.replicas,
      ReadyReplicas: @deployment.status.readyReplicas
    }

    begin
      # If we have a selector, let's look at any running pods that match
      label_selector = []
      @deployment.spec&.selector&.matchLabels&.each_pair do |label, value|
        label_selector << "#{label}=#{value}"
      end

      @pods = settings.k8core.get_pods(namespace: ns, label_selector: label_selector.join(','))
    rescue KubeClient::ResourceNotFoundError
      @pods = nil
    end

    # Last but not least, let's make some crumbs
    @crumbs = {
      'Namespaces' => '',
      @deployment.metadata.namespace => link_for(:namespace, @deployment.metadata.namespace),
      @deployment.metadata.name => ''
    }

    if @deployment.nil?
      'Deployment not found.'
    else
      slim :deployment
    end
  end
end
