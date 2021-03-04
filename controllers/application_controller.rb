# frozen_string_literal: true

require 'application_helpers'
require 'config'
require 'display_helpers'
require 'sassc'
require 'sinatra/base'
require 'sinatra/flash'
require 'sinatra/param'
require 'sinatra/respond_with'
require 'sinatra/validation'

require 'report'
require_relative '../connectors/kubectl'

# Base class for all Controllers
class ApplicationController < Sinatra::Base
  set :root, File.expand_path('..', __dir__)

  # register extends the Sinastra DSL
  register Config
  register Sinatra::Flash
  register Sinatra::RespondWith
  register Sinatra::Validation

  # helpers extend the Request context
  helpers Sinatra::Param
  helpers ApplicationHelpers
  helpers DisplayHelpers

  # settings
  enable :logging
  enable :sessions
  set :javascripts, [
    'jquery.min.js',
    'popper.min.js',
    'bootstrap.min.js',
    'mdb.min.js',
    'bms.js'
  ]
  set :title, 'BMS'

  # Everyone loves some kubernetes...
  begin
    opts = {
      url: Settings&.kubernetes&.url,
      auth_options: Settings&.kubernetes&.auth_options&.to_h,
      ssl_options: Settings&.kubernetes&.ssl_options&.to_h
    }
    set :k8core, KubeCtl.core(**opts)
    set :k8apps, KubeCtl.apps(**opts)
    set :k8extensions, KubeCtl.extensions(**opts)
    set :k8metrics, KubeCtl.metrics(**opts)
  end

  before '/*' do
    @latest_reports = Report.latest_timestamps
    @active_app = self.class.name.chomp('Controller').downcase

    # To have the ability to change response type with an extension
    # eg: http://example.org/record.json => Accept: application/json
    if request.url.match(/\.json$/)
      request.accept.unshift('application/json')
      request.path_info.gsub!(/\.json$/, '')
    end
  end

  get '/' do
    redirect '/dashboard'
  end

  get '/css/styles.css' do
    scss :styles
  end

  get '/health' do
    return '{ "status": "green" }'
    # health = { status: 'green' }
    # # Check database status
    # health[:latest_report] = Report.latest.first.timestamp

    # health[:database] = if port_open?(6379)
    #                       'green'
    #                     else
    #                       'red'
    #                     end
    # case health[:status]
    # when 'yellow'
    #   status 501
    # when 'red'
    #   status 503
    # end
    # JSON.generate(health)
  end

  not_found do
    "I don't know what you want."
  end
end
