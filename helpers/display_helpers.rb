# frozen_string_literal: true

# Helpers for displaying data
module DisplayHelpers
  require 'active_support'
  require 'active_support/core_ext/numeric/conversions'
  require 'active_support/core_ext/string/inflections'

  # Setup acronyms used in reports.
  ActiveSupport::Inflector.inflections(:en) do |inflect|
    inflect.acronym 'BMS'
    inflect.acronym 'CPU'
    inflect.acronym 'URI'
    inflect.acronym 'URIs'
    inflect.acronym 'URL'
    inflect.acronym 'URLs'
    inflect.acronym 'RAM'
  end

  ##
  # Does a very simple check taking the name of a variable to use to check the
  # value against +value+

  def active?(variable, value, string = 'active')
    eval("@#{variable} == '#{value}'") ? string : '' # rubocop:disable all
  end

  def active_app?(app)
    app = [app] if app.is_a? String
    app.include?(@active_app) ? 'active' : ''
  end

  def bootstrap_class_for(type)
    case type
    when :success
      'alert-success'
    when :error
      'alert-danger'
    when :alert
      'alert-warning'
    when :notice
      'alert-info'
    else
      type.to_s
    end
  end

  def current?(path = '/')
    request.path_info == path ? 'current' : nil
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

  def parse_percentage(percentage, percision: 0)
    percentage = percentage.round(percision)
    payload = { value: percentage }
    payload[:text] = "#{percentage}%"
    payload[:bg] = case percentage
                   when 90..100
                     'bg-danger'
                   when 75..89
                     'bg-warning'
                   else
                     'bg-success'
                   end
    payload
  end

  def display_time(timestamp)
    Time.at(timestamp).strftime('%B %e, %Y %l:%M%P')
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
    value.to_s.gsub(/ip-[0-9]{1,3}-[0-9]{1,3}/, 'ip-x-x')
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
end
