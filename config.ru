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
layout = case Settings&.logging&.layout
         when 'json'
           Logging.layouts.json
         when 'yaml'
           Logging.layouts.yaml
         else
           Logging.layouts.basic
         end
# Setup root logger
Logging.logger.root.appenders = Logging.appenders.stdout(layout: layout)
Logging.logger.root.level = Settings&.logging&.level || :warn
# format_as is how Logging translates ruby objects to string in log
Logging.format_as Settings&.logging&.format_as || :inspect

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

# Load all our application requirements
%w[connectors helpers controllers].each do |dir|
  $LOAD_PATH.unshift(File.expand_path(dir, __dir__))
  Dir.glob("./#{dir}/**/*.rb").sort.each { |file| require file }
end

map('/apps')        { run AppsController }
map('/dashboard')   { run DashboardController }
map('/deployments') { run DeploymentsController }
map('/labels')      { run LabelsController }
map('/nodes')       { run NodesController }
map('/ns')          { run NamespaceController }
map('/report')      { run ReportsController }
map('/')            { run ApplicationController }
