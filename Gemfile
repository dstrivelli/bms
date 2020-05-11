# frozen_string_literal: true

# We use http instead of https because if we build on the VA network then
# our download requests fail.
source 'http://rubygems.org'

ruby '2.6.5'

gem 'activesupport'         # Adds helper methods
gem 'config'                # Global application Settings
gem 'daybreak'              # kv datastore
gem 'httparty'              # Fun with HTTP
gem 'json'
gem 'kubeclient'            # Gather information from Kubernetes
gem 'logging'
gem 'mail'                  # Send emails
gem 'ohm'                   # Use Ohm for Redis backend
gem 'ohm-contrib'           # Helpful additions to Ohm
gem 'prometheus-api-client' # Gather information from Prometheus
gem 'roadie'                # In-line CSS for emails
gem 'sassc'                 # SASS Compiler
gem 'sinatra'
gem 'sinatra-flash'         # Nice alert notifications in pages
gem 'sinatra-validation'    # Validate params in Sinatra
gem 'slim'                  # Templating
gem 'thin'                  # Use Thin for web handler

group :development do
  gem 'lp'                  # Easy output of Objects in yaml
  gem 'pry'                 # Debugging
  gem 'pry-byebug'
  gem 'pry-remote'
  gem 'pry-rescue'
  gem 'sinatra-contrib'     # Gives us access to sinatra/reloader
end

group :test do
  gem 'capybara'
  gem 'factory_bot'         # Use FactoryBot to mock objects
  gem 'ffaker'              # Generate random string/urls/etc
  gem 'rack-test'
  gem 'rspec'
  gem 'rspec-html-matchers'
  gem 'vcr'                 # Record and playback http requests
  gem 'webmock'             # Mock http requests
end
