# frozen_string_literal: true

require 'daybreak'
require 'sinatra/base'

# We are extending the Sinatra module
module Sinatra
  # This module is for Sinatra helper methods
  module BMSHelpers
    require 'active_support'
    require 'active_support/core_ext/numeric/conversions'
    require 'active_support/core_ext/string/inflections'

    ActiveSupport::Inflector.inflections(:en) do |inflect|
      inflect.acronym 'BMS'
      inflect.acronym 'CPU'
      inflect.acronym 'URI'
      inflect.acronym 'URIs'
      inflect.acronym 'URL'
      inflect.acronym 'URLs'
      inflect.acronym 'RAM'
    end

    def worker_pid
      # Validate pid file exists
      pid = File.read('/tmp/bms_worker.pid').to_i
      return nil if pid.zero?

      # Validate process is still running
      Process.getpgid(pid)
      pid
    rescue Errno::ENOENT, Errno::ESRCH
      nil
    end

    def worker_running?
      worker_pid ? true : false
    end

    def display_heading(name)
      name = name.to_s
      name.slice!(/_percent$/)
      name.titleize
    end

    def display_value(name, value)
      name = name.to_s
      method_name = "display_#{value.class.name.downcase}"
      if respond_to? method_name
        send(method_name, name, value)
      else
        send(:display_string, name, value)
      end
    end

    def display_array(name, value, delimiter = ', ')
      display_string(name, value.join(delimiter))
    end

    def display_string(_name, value)
      value.to_s
    end

    def display_number(name, value)
      if name.end_with?('_percent')
        value.to_s(:percentage, precision: 0)
      else
        value
      end
    end
    alias display_integer display_number
    alias display_float   display_number
  end # Sinatra::BMS_Helpers

  helpers BMSHelpers
end # Sinatra
