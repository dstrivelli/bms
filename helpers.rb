module Helpers
  require 'active_support'
  require 'active_support/core_ext/numeric/conversions'
  require 'active_support/core_ext/string/inflections'

  ActiveSupport::Inflector.inflections(:en) do |inflect|
    inflect.acronym 'CPU'
    inflect.acronym 'RAM'
  end

  def partial(name, locals)
    name = name.to_s
    name += '.slim' unless name.end_with? '.slim'
    options = { pretty: true }
    Slim::Template.new("views/_#{name}", options).render(self, locals)
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

  def display_array(name, value)
    display_string(name, value.join(', '))
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

class Context < OpenStruct
  include Helpers
  def keys
    @table.keys.map(&:to_s)
  end
end
