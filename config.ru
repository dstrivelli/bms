# frozen_string_literal: true

require 'config'
require 'logging'
require 'mail'
require 'ohm'
require 'sinatra/base'

env = ENV.fetch('APP_ENV', 'development')

# Sync STDOUT so we see msgs in foreman
STDOUT.sync = true

# Load some dev stuff
if env == 'development'
  begin
    require 'pry'
    require 'pry-remote'
  rescue LoadError
    nil
  end
end

# Load settings first.
Config.setup do |config|
  config.use_env = true
  config.env_prefix = 'BMS'
  config.env_separator = '__'
end
Config.load_and_set_settings(
  Config.setting_files(File.join(__dir__, 'config'), env)
)

# Initialize logging
Logging.logger.root.appenders = Logging.appenders.stdout # (layout: Logging.layouts.basic)
Logging.logger.root.level = Settings&.log_level || :warn
# Example of how to fine tune logging
# Logging.logger['BMS::Worker'].level = :info

# Initialize Mail
mail_defaults = {
  address: 'smtp.va.gov',
  port: 25
}
manner = Settings&.email&.manner || :smtp
options = Settings&.email&.options || mail_defaults
Mail.defaults do
  delivery_method manner, options
end

# Configure redis
redis_host = Settings&.redis || 'redis://127.0.0.1:6379'
Ohm.redis = Redic.new(redis_host)

# Load all our application requirements
%w[connectors models helpers controllers].each do |dir|
  $LOAD_PATH.unshift(File.expand_path(dir, __dir__))
  Dir.glob("./#{dir}/**/*.rb").sort.each { |file| require file }
end

map('/dashboard') { run DashboardController }
map('/labels')    { run LabelsController }
map('/reports')   { run ReportsController }
map('/')          { run ApplicationController }
