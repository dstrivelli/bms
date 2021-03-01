# frozen_string_literal: true

require 'json'

require 'application_controller'

# Controller to handle health reports
class NamespaceController < ApplicationController
  get '/v2/:name' do
    param :name, String, required: true

    v1 = KubeCtl.new(
      Settings&.kubernetes&.url,
      auth_options: Settings&.kubernetes&.auth_options&.to_h,
      ssl_options: Settings&.kubernetes&.ssl_options&.to_h,
    )
    extensions = KubeCtl.new(
      URI.join(Settings&.kubernetes&.url, '/apis/extensions'),
      'v1beta1',
      auth_options: Settings&.kubernetes&.auth_options&.to_h,
      ssl_options: Settings&.kubernetes&.ssl_options&.to_h,
    )

    #binding.pry
    @namespace = v1.get_namespace(params[:name])
    @deployments = extensions.get_deployments(namespace: params[:name])
    @pods = v1.get_pods(namespace: params[:name])
    @events = v1.get_events(namespace: params[:name])

    heading "Namespace: #{@namespace&.metadata&.name || 'Unknown'}"

    respond_to do |format|
      format.html { slim :v2namespace }
    end
  end

  get '/:id' do
    param :id, String, required: true

    @namespace = if params[:id] =~ /\A[0-9]*\Z/
                   Namespace[params[:id]]
                 else
                   Namespace.with(:name, params[:id])
                 end
    return slim('p No namespace with that id/name.') if @namespace.nil?

    @events = @namespace.events.sort_by(:lastTimestamp, order: 'DESC')

    heading "Namespace: #{@namespace&.name || 'Unknown'}"

    respond_to do |format|
      format.html { slim :namespace }
      # format.json { @payload.to_json }
    end
  end
end
