# frozen_string_literal: true

# require 'capybara'
require 'config'
require 'logging'
require 'mail'
require 'pry'
require 'rack/test'
require 'rspec'
require 'rspec-html-matchers'

# TODO: Remove this eventually when moved everything out of lib
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# Add all our app directories to load_path
%w[connectors controllers models helpers].each do |dir|
  $LOAD_PATH.unshift(File.expand_path("../#{dir}", __dir__))
end

# Set environment
ENV['APP_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'

# Load settings first.
Config.setup do |config|
  config.use_env = true
  config.env_prefix = 'BMS'
  config.env_separator = '__'
end
Config.load_and_set_settings(
  Config.setting_files(File.expand_path('../config', __dir__), 'test')
)
Settings.env = 'test'

# Load in all our needed matchers
RSpec.configure do |c|
  # Allow only expect syntax
  c.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
  # Include matchers
  c.include Rack::Test::Methods
  c.include RSpecHtmlMatchers
  c.include Mail::Matchers
end

RSpec::Matchers.define(:redirect_to) do |url|
  match do |response|
    response.status == 302 && response.headers['Location'] == url
  end
end

# Load our testing support suite
Dir.glob(File.expand_path('support/**/*.rb', __dir__)).sort.each { |file| require file }
