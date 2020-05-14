# frozen_string_literal: true

require 'ohm'
require 'ohm/contrib'

##
# Model to describe kubernetes containers
class Container < Ohm::Model
  include Ohm::DataTypes

  reference :pod, :Pod

  attribute :name
  index :name
  attribute :image
  attribute :liveness_probe
  attribute :readiness_probe
  attribute :env, Type::Hash
  attribute :cpu_requests, Type::Float
  attribute :ram_requests, Type::Float
  attribute :cpu_limits, Type::Float
  attribute :ram_limits, Type::Float

  # To allow FactoryBot to play nicely
  alias save! save
end
