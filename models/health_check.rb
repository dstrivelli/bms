# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/numeric/time'
require 'ohm'
require 'ohm/contrib'

##
# Model to describe health checks to urls
class HealthCheck < Ohm::Model
  include Ohm::Callbacks

  reference :report, :Report

  attribute :name
  attribute :uri
  attribute :result

  protected

  def after_save
    redis.call 'EXPIRE', key, 90.days
  end

  alias save! save
end
