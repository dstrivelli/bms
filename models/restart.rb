# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/numeric/time'
require 'ohm'
require 'ohm/contrib'

##
# Model to describe pod restarts
class Restart < Ohm::Model
  include Ohm::Callbacks

  reference :report, :Report

  attribute :namespace
  attribute :pod
  attribute :count

  protected

  def after_save
    redis.call 'EXPIRE', key, 90.days
  end
end
