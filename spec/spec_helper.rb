# frozen_string_literal: true

$LOAD_PATH << File.expand_path(File.join(__dir__, '../lib'))

# Set environment
ENV['APP_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'

require 'bms'
require 'logging'
require 'rack/test'
require 'rspec'

# Turn off logging
Logging.logger.root.appenders = nil
