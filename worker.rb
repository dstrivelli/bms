#!/usr/bin/env ruby

# Add lib dir to path
$: << File.join(__dir__, 'lib')
$stdout.sync = true

require 'config'
require 'daybreak'
require 'pry'

require 'bms/worker'

# Load settings
Config.setup do |config|
  config.use_env = true
  config.env_prefix = 'BMS'
  config.env_separator = '__'
end
Config.load_and_set_settings(Config.setting_files(File.join(__dir__, 'config'), 'production'))

worker = BMS::Worker.new
