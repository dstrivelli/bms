# frozen_string_literal: true

require 'json'
require 'mail'

require 'application_controller'

# Controller to handle health reports
class DashboardController < ApplicationController
  get '/' do
    @nodes = Node.all
    @apps = Namespace.apps
    @healthchecks = HealthCheck.all
    @namespaces = Namespace.all
    @orphans = @namespaces.find(app: 'nil')

    heading 'BMS Dashboard'

    respond_to do |format|
      format.html { slim :dashboard }
      format.json { @payload.to_json }
    end
  end
end
