# frozen_string_literal: true

require 'display_helpers'
require 'sassc'
require 'sinatra/base'
require 'sinatra/flash'

# Base class for all Controllers
class ApplicationController < Sinatra::Base
  set :root, File.expand_path('..', __dir__)
  enable :sessions

  register Config
  register Sinatra::Flash

  helpers DisplayHelpers

  before '/*' do
    @latest_reports = BMS::DB.runs[0..4]
    @active_app = self.class.name.chomp('Controller').downcase
  end

  get '/' do
    redirect '/reports/latest'
  end

  get '/css/styles.css' do
    scss :styles
  end

  not_found { "I don't know what you want. Go back I guess." }
end
