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

# Load all our application requirements
%w[models helpers controllers].each do |dir|
  $LOAD_PATH.unshift(File.expand_path(dir, __dir__))
  Dir.glob("./#{dir}/**/*.rb").sort.each { |file| require file }
end

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
  # Initialize logging
  Logging.logger.root.appenders = Logging.appenders.stdout # (layout: Logging.layouts.basic)
  Logging.logger.root.level = Settings&.log_level || :warn
  # Example of how to fine tune logging
  # Logging.logger['BMS::Worker'].level = :info

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
