# frozen_string_literal: true

require 'json'
require 'mail'

require 'application_controller'

# Controller to handle health reports
class DashboardController < ApplicationController
  get '/' do
    @header = 'BMS Dashboard'
    @nodes = Node.all
    @apps = []
    Namespace.apps.each do |app|
      @apps << { name: app, namespaces: Namespace.find(app: app).map(&:to_report_hash) }
    end
    @namespaces = Namespace.all
    @deployments = Deployment.all
    @payload = {
      'nodes' => @nodes.map(&:attributes),
      'namespaces' => @namespaces.map(&:to_report_hash)
    }
    respond_to do |format|
      format.html { slim :dashboard }
      format.json { @payload.to_json }
    end
  end
end
