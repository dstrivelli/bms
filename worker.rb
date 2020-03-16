#!/usr/bin/env ruby
# frozen_string_literal: true

# Add lib dir to path
$LOAD_PATH << File.join(__dir__, 'lib')
$stdout.sync = true

require 'config'
require 'daybreak'
require 'fileutils'
require 'bms'
require 'bms/worker'

# Try to load Pry if it's available
begin
  require 'pry'
rescue LoadError
  nil
end

pid_file = '/tmp/bms_worker.pid'
if File.exist? pid_file
  puts 'Only one instance of worker can run at a time.'
  puts 'If this in error, remove ' + pid_file
  exit 1
else
  File.open(pid_file, 'w') { |f| f.write Process.pid }
end

begin
  # Load settings
  Config.setup do |config|
    config.use_env = true
    config.env_prefix = 'BMS'
    config.env_separator = '__'
  end
  env = ENV.fetch('APP_ENV', 'development')
  Config.load_and_set_settings(
    Config.setting_files(File.join(__dir__, 'config'), env)
  )
  Settings.env = env
  BMS::DB.load(Settings.db)

  # Start worker
  BMS::Worker.new
rescue Interrupt
  puts 'INTERRUPTED'
rescue SignalException => e
  retry if e.signm == 'SIGHUP'
  raise
ensure
  FileUtils.rm(pid_file, force: true)
end
