# frozen_string_literal: true

require 'active_support/core_ext/hash/except'
require 'ohm'
require 'ohm/contrib'

# Require other models
require_relative 'node'
require_relative 'restart'
require_relative 'unhealthy_pod'
require_relative 'health_check'

##
# Model class to describe a BMS health check report
#
class Report < Ohm::Model
  include Ohm::Callbacks
  include Ohm::DataTypes

  attribute :timestamp, Type::Integer
  index :timestamp
  attribute :complete, Type::Boolean
  index :complete

  set :errors, :Error

  collection :nodes, :Node
  collection :restarts, :Restart
  collection :unhealthy_pods, :UnhealthyPod
  collection :health_checks, :HealthCheck

  def self.latest(count = 5)
    fetch(redis.call('ZREVRANGE', key[:latest], 0, (count - 1)))
  end

  def self.latest_timestamps(count = 5)
    latest(count).each_with_object([]) { |node, arr| arr << node.timestamp }
  end

  def to_h
    h = {}
    h[:timestamp] = timestamp
    h[:nodes] = nodes.each_with_object([]) do |node, obj|
      obj << node.attributes.except(:report_id)
    end
    h[:restarts] = restarts.each_with_object([]) do |restart, obj|
      obj << restart.attributes.except(:report_id)
    end
    h[:unhealthy_pods] = unhealthy_pods.each_with_object([]) do |pod, obj|
      obj << pod.attributes.except(:report_id)
    end
    h[:health_checks] = health_checks.each_with_object([]) do |check, obj|
      obj << check.attributes.except(:report_id)
    end
    to_hash.merge(h)
  end

  def to_s
    "BMS Health Report - #{Time.at(timestamp).strftime('%B %e, %Y %l:%M:%P')}"
  end

  protected

  def before_create
    complete ||= false # rubocop:disable Lint/UselessAssignment
  end

  def after_save
    redis.call('ZADD', model.key[:latest], timestamp, id) if complete
    redis.call('EXPIRE', key, 90.days)
  end

  def after_delete
    # Remove from latest
    redis.call('ZREM', model.key[:latest], id)

    # Delete collections
    nodes.each(&:delete)
    restarts.each(&:delete)
    unhealthy_pods.each(&:delete)
  end

  # to use factory_bot we need to alias save
  alias save! save
end
