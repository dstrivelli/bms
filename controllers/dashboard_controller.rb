# frozen_string_literal: true

require 'json'
require 'mail'

require 'application_controller'
require 'display_helpers'
require 'email_helpers'

# Controller to handle health reports
class DashboardController < ApplicationController
  get '/' do
    @header = 'BMS Dashboard'
    @nodes = Node.all
    @namespaces = Namespace.all
    @deployments = Deployment.all
    slim :dashboard
  end
end
