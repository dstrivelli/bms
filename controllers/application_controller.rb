# frozen_string_literal: true

require 'config'
require 'display_helpers'
require 'sassc'
require 'sinatra/base'
require 'sinatra/flash'
require 'sinatra/validation'

require 'report'

# Base class for all Controllers
class ApplicationController < Sinatra::Base
  set :root, File.expand_path('..', __dir__)
  enable :sessions

  register Config
  register Sinatra::Flash
  register Sinatra::Validation

  helpers DisplayHelpers

  before '/*' do
    @latest_reports = Report.latest_timestamps
    @active_app = self.class.name.chomp('Controller').downcase
  end

  get '/' do
    redirect '/reports/latest'
  end

  get '/css/styles.css' do
    scss :styles
  end

  get '/health' do
    return "{ status: 'green' }"
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

  not_found { "I don't know what you want. Go back I guess." }
end
