# frozen_string_literal: true

require 'json'

require 'application_controller'

# Controller to handle displaying apps
class AppsController < ApplicationController
  get '/:app' do
    @app = params[:app]
    @namespaces = Namespace.find(app: params[:app]).sort(by: :name, order: 'ASC ALPHA')
    @empty_namespaces = []
    @namespaces.each { |ns| @empty_namespaces << ns.name if ns.deployments.empty? }
    @header = "App: #{params[:app]}"
    @caption = "Empty namespaces: #{@empty_namespaces.join(', ')}" unless @empty_namespaces.empty?
    # Display
    respond_to do |format|
      format.html { slim :app }
      format.json { @payload.to_json }
    end
  end
end
