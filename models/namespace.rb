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

  def to_report_hash
    {
      name: name,
      annotations: annotations,
      labels: labels,
      deployments: deployments.map(&:to_report_hash)
    }
  end

  # To allow FactoryBot to play nicely
  alias save! save
end
