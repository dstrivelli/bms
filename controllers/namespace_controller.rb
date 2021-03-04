# frozen_string_literal: true

require 'json'
require 'uri'

require 'application_controller'

# Controller to handle health reports
class NamespaceController < ApplicationController
  get '/:name' do
    param :name, String, required: true

    ns = params[:name]

    @namespace = settings.k8core.get_namespace(ns)
    unless @namespace.nil?
      @configmaps = settings.k8core.get_config_maps(namespace: ns)
      @daemonsets = settings.k8extensions.get_daemon_sets(namespace: ns, sort_by: '.metadata.name')
      @deployments = settings.k8extensions.get_deployments(namespace: ns)
      @ingresses = settings.k8extensions.get_ingresses(namespace: ns)
      @secrets = settings.k8core.get_secrets(namespace: ns)
      @services = settings.k8core.get_services(namespace: ns)
      @statefulsets = settings.k8apps.get_stateful_sets(namespace: ns, sort_by: '.metadata.name')
      @pods = settings.k8core.get_pods(namespace: ns, sort_by: '.metadata.name')
      @events = settings.k8core.get_events(namespace: ns, sort_by: '.lastTimestamp')
    end

    @crumbs = {
      'Namespaces' => '',
      ns => ''
    }

    respond_to do |format|
      if @namespace.nil?
        format.html 'No namespace found.'
      else
        format.html { slim :namespace }
      end
    end
  end
end
