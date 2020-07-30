# frozen_string_literal: true

require 'ohm'
require 'ohm/contrib'

##
# Model to describe health checks to urls
class HealthCheck < Ohm::Model
  #include Ohm::Callbacks
  include Ohm::DataTypes

  attribute :name
  unique :name
  attribute :uri
  attribute :result
  attribute :details
  attribute :healthy, Type::Boolean

  def to_report_hash
    {
      name: name,
      uri: uri,
      result: result
    }
  end

  alias save! save
end
