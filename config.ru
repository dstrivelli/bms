# frozen_string_literal: true

$LOAD_PATH << File.expand_path('lib', __dir__)

require 'config'
require 'sinatra/base'

require 'bms/db'

# Load settings first.
Config.setup do |config|
  config.use_env = true
  config.env_prefix = 'BMS'
  config.env_separator = '__'
end
env = ENV.fetch('APP_ENV', 'development')
Config.load_and_set_settings(
  Config.setting_files(File.join(__dir__, 'config'), env)
)

# Initialize the database
BMS::DB.load(Settings.db)

# Load some dev stuff
if env == 'development'
  begin
    require 'pry'
    require 'pry-remote'
  rescue LoadError
    nil
  end
end

# Load all our application requirements
%w[models helpers controllers].each do |dir|
  Dir.glob("./#{dir}/**/*.rb").sort.each { |file| require file }
end

map('/labels')  { run LabelsController }
map('/reports') { run ReportsController }
map('/')        { run ApplicationController }
