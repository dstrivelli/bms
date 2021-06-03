# frozen_string_literal: true

require 'faraday'
require 'json'
require 'uri'

require 'application_controller'

# Controller to handle health reports
class DashboardController < ApplicationController
  get '/' do
    @api_url = URI(Settings.api.external)
    @api_url.scheme = @api_url.scheme == 'https' ? 'wss' : 'ws'

    conn = Faraday.new(Settings.api.internal, request: { timeout: 5 })

    begin
      resp = conn.get('/health/nodes')
      @nodes = JSON.parse(resp.body, { symbolize_names: true })
    rescue => e # rubocop:disable Style/RescueStandardError
      logger.error e
      @nodes = []
    end

    begin
      resp = conn.get('/health/namespaces')
      namespaces = JSON.parse(resp.body, { symbolize_names: true })
      # Take the list of namespaces and sort them into grouped by tenant
      @tenants = namespaces.each_with_object({}) do |ns, tenants|
        name = ns[:tenant].to_s
        if tenants[name].nil?
          tenants[name] = [ns]
        else
          tenants[name] << ns
        end
      end
      # Sort that list
      @tenants = @tenants.sort.to_h
      @tenants.each do |k, v|
        @tenants[k] = v.sort_by { |env| env[:name] }
      end
    rescue => e # rubocop:disable Style/RescueStandardError
      logger.error e
      @tenants = []
    end

    begin
      resp = conn.get('/health/urls')
      @urlchecks = JSON.parse(resp.body, { symbolize_names: true })
    rescue => e # rubocop:disable Style/RescueStandardError
      logger.error e
      @urlchecks = []
    end

    # heading 'BMS Dashboard'

    respond_to do |format|
      format.html { slim :dashboard }
      format.json do
        {
          nodes: @nodes,
          tenants: @tenants,
          urlchecks: @urlchecks
        }.to_json
      end
    end
  end
end
