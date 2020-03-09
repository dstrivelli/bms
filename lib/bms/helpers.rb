require 'sinatra/base'

module Sinatra
  module BMS_Helpers
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

    def display_heading(name)
      name = name.to_s
      name.slice!(/_percent$/)
      name.titleize
    end

    def display_value(name, value)
      method_name = "display_#{value.class.name.downcase}"
      if self.respond_to? method_name
        self.send(method_name, name, value)
      else
        self.send(:display_string, name, value)
      end
    end

    def display_array(name, value, delimiter = ', ')
      display_string(name, value.join(delimiter))
    end

    def display_string(name, value)
      value.to_s
    end

    def display_number(name, value)
      case
      when name.end_with?('_percent')
        value.to_s(:percentage, precision: 0)
      else
        value
      end
    end
    alias_method :display_integer, :display_number
    alias_method :display_float, :display_number
  end

  helpers BMS_Helpers
end
