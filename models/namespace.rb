# frozen_string_literal: true

require 'ohm'
require 'ohm/contrib'

##
# Model to describe kubernetes namespaces
class Namespace < Ohm::Model
  include Ohm::DataTypes

  attribute :name
  unique :name
  attribute :annotations, Type::Hash
  attribute :labels, Type::Hash
  collection :deployments, :Deployment
  collection :pods, :Pod

  # To allow FactoryBot to play nicely
  alias save! save
end
