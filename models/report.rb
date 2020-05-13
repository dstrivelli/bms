# frozen_string_literal: true

require 'active_support/core_ext/hash/except'
require 'ohm'
require 'ohm/contrib'

##
# Model class to describe a BMS health check report
#
class Report < Ohm::Model
  include Ohm::Callbacks
  include Ohm::DataTypes

  attribute :timestamp, Type::Integer
  index :timestamp
  attribute :nodes, Type::Array
  attribute :restarts, Type::Array
  attribute :unhealthy_pods, Type::Array
  attribute :health_checks, Type::Array

  def self.latest(count = 5)
    fetch(redis.call('ZREVRANGE', key[:latest], 0, (count - 1)))
  end

  def self.latest_timestamps(count = 5)
    latest(count).each_with_object([]) { |node, arr| arr << node.timestamp }
  end

  def to_s
    "BMS Health Report - #{Time.at(timestamp).strftime('%B %e, %Y %l:%M:%P')}"
  end

  protected

  def after_save
    # Add to latest
    redis.call('ZADD', model.key[:latest], timestamp, id)
  end

  def after_delete
    # Remove from latest
    redis.call('ZREM', model.key[:latest], id)
  end

  # to use factory_bot we need to alias save
  alias save! save
end
