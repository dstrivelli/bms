# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'sinatra/base'
require 'slim'
require 'sassc'

# Base class for all Controllers
class ApplicationController < Sinatra::Base
  set :root, File.expand_path('..', __dir__)

  get '/' do
    redirect '/reports/latest'
  end

  get '/css/styles.css' do
    scss :styles
  end

  # not_found{ 'not found' }
end
