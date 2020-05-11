# frozen_string_literal: true

require 'ohm'

##
# Class to simplify requests to the Redis database
class Redis
  def initialize
    nil
  end

  def [](key)
    Ohm.call 'GET', key
  end

  def []=(key, value)
    Ohm.call 'SET', key, value
  end

  def key?(key)
    result = Ohm.call 'KEYS', key
    !result.empty?
  end
end
