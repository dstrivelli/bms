# frozen_string_literal: true

require 'ohm'
require 'ohm/contrib'

##
# Model to describe kubernetes pods
class Event < Ohm::Model
  include Ohm::DataTypes

  reference :namespace, :Namespace

  attribute :uid
  unique :uid
  attribute :name
  attribute :kind
  index :kind
  attribute :lastTimestamp, Type::Time
  attribute :message
  attribute :reason

  # To allow FactoryBot to play nicely
  alias save! save
end
