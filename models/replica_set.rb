# frozen_string_literal: true

require 'ohm'

##
# Model to describe kubernetes containers
class ReplicaSet < Ohm::Model
  reference :namespace, :Namespace
  reference :deployment, :Deployment

  attribute :name
  index :name
  attribute :uid
  unique :uid

  # To allow FactoryBot to play nicely
  alias save! save
end
