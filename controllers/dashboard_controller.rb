# frozen_string_literal: true

require 'faraday'
require 'json'

require 'application_controller'

# Controller to handle health reports
class DashboardController < ApplicationController
  get '/' do
    @nodes = Node.all
    @apps = Namespace.apps
    @healthchecks = HealthCheck.all
    @namespaces = Namespace.all
    @orphans = @namespaces.find(app: 'nil')

    begin
      resp = Faraday.get 'http://127.0.0.1:8080/health/urls'
      @urlchecks = JSON.parse(resp.body, { symbolize_names: true } )
    rescue
      @urlchecks = nil
    end

    heading 'BMS Dashboard'

    respond_to do |format|
      format.html { slim :dashboard }
      format.json { @payload.to_json }
    end
  end
end
