# frozen_string_literal: true

require 'display_helpers'
require 'sinatra/base'
require 'sinatra/flash'
require 'sassc'

# Base class for all Controllers
class ApplicationController < Sinatra::Base
  set :root, File.expand_path('..', __dir__)
  enable :sessions
  register Sinatra::Flash

  helpers DisplayHelpers

  get '/' do
    redirect '/reports/latest'
  end

  get '/css/styles.css' do
    scss :styles
  end

  get '/test' do
    flash.now[:notice] = 'Test notification.'
    slim 'Test Body'
  end

  not_found { "I don't know what you want. Go back I guess." }
end
