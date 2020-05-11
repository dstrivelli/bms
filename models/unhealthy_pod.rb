# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/numeric/time'
require 'ohm'
require 'ohm/contrib'

##
# Model to describe unhealthy kubernetes pods
class UnhealthyPod < Ohm::Model
  include Ohm::Callbacks

  reference :report, :Report

  attribute :namespace
  attribute :pod
  attribute :state

  protected

  def after_save
    redis.call 'EXPIRE', key, 90.days
  end

  # To allow FactoryBot to play nicely
  alias save! save
end
