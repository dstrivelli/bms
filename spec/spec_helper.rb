# frozen_string_literal: true

require 'pry'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

%w[controllers models helpers].each do |dir|
  $LOAD_PATH.unshift(File.expand_path("../#{dir}", __dir__))
end

# Set environment
ENV['APP_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'

require 'bms/db'
require 'capybara'
require 'config'
require 'logging'
require 'mail'
require 'pry'
require 'rack/test'
require 'rspec'
require 'rspec-html-matchers'
require 'webmock/rspec'
require 'vcr'

# Configure VCR to record http requests
VCR.configure do |c|
  c.cassette_library_dir = File.expand_path 'fixtures/cassettes', __dir__
  c.hook_into :webmock
  c.default_cassette_options = { record: :new_episodes }
  c.configure_rspec_metadata!
end

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

# Load settings first.
Config.setup do |config|
  config.use_env = true
  config.env_prefix = 'BMS'
  config.env_separator = '__'
end
env = ENV.fetch('APP_ENV', 'development')
Config.load_and_set_settings(
  Config.setting_files(File.expand_path('../config', __dir__), env)
)

# Initialize the database
def load_db
  BMS::DB.load(Settings.db)
end
load_db

# Turn off logging
Logging.logger.root.level = Settings&.log_level || :warn

# Turn off actually sending emails
Mail.defaults do
  delivery_method :test
end

# Disable external http requests
WebMock.disable_net_connect!(allow_localhost: true)
