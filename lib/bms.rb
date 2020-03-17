# frozen_string_literal: true

# These are required before everything else
require 'logging'

# Setup logging before we load subclasses
Logging.logger.root.appenders = Logging.appenders.stdout#(layout: Logging.layouts.basic)
Logging.logger.root.level = :debug
# Example of how to fine tune logging
# Logging.logger['BMS::Worker'].level = :info

# Load any BMS classes we need for everyone
require 'bms/db'
require 'bms/result'

# The default namespace for BMS
module BMS
  def self.log_level=(level)
    Logging.logger.root.level = level
  end

  CPU_ORDERS_OF_MAGNITUDE = {
    m: 1000,
    n: 1_000_000_000
  }.freeze

  RAM_ORDERS_OF_MAGNITUDE = {
    Ki: 1000,
    Mi: 1_000_000
  }.freeze

  def self.convert_cores(cores)
    unit = cores[-1].to_sym
    count = cores[0..-2].to_f
    if CPU_ORDERS_OF_MAGNITUDE[unit]
      (count / CPU_ORDERS_OF_MAGNITUDE[unit]).round(2)
    else
      count.round(2)
    end
  end

  def self.convert_ram(ram)
    unit = ram[-2].to_sym
    count = ram[0..-3].to_f
    if RAM_ORDERS_OF_MAGNITUDE[unit]
      (count / RAM_ORDERS_OF_MAGNITUDE[unit]).round(2)
    else
      count.round(2)
    end
  end
end # BMS
