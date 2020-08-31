# frozen_string_literal: true

require 'ohm'
require 'ohm/contrib'

##
# Model to describe kubernetes namespaces
class Namespace < Ohm::Model
  include Ohm::Callbacks
  include Ohm::DataTypes

  attribute :name
  unique :name
  attribute :uid
  unique :uid
  attribute :app
  index :app
  attribute :env
  index :env
  attribute :annotations, Type::Hash
  attribute :labels, Type::Hash
  collection :deployments, :Deployment
  collection :replica_sets, :ReplicaSet
  collection :pods, :Pod
  collection :events, :Event

  def to_report_hash
    {
      name: name,
      annotations: annotations,
      labels: labels,
      deployments: deployments.map(&:to_report_hash)
    }
  end

  def self.apps
    values = []
    all.each do |ns|
      values << ns.app if ns.app && ns.app != 'nil'
    end
    values.uniq.sort
  end

  # To allow FactoryBot to play nicely
  alias save! save

  protected

  def before_save
    regex = /^(?<app>[a-zA-Z0-9_\-]+)-(?<env>prod|prodtest|preprod|perf|cola)$/
    if (matches = regex.match(name))
      self.app = matches.named_captures['app']
      self.env = matches.named_captures['env']
    else
      self.app = 'nil'
      self.env = 'nil'
    end
  end
end
