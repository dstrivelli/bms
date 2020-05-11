# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/numeric/time'
require 'ohm'
require 'ohm/contrib'

##
# Model to describe Kubernetes nodes
class Node < Ohm::Model
  include Ohm::Callbacks
  include Ohm::DataTypes

  #reference :report, :Report

  attribute :name
  attribute :hostname
  attribute :internal_ip
  attribute :annotations, Type::Hash
  attribute :labels, Type::Hash
  attribute :kernel_version
  attribute :kubelet_version
  attribute :conditions, Type::Array
  attribute :cpu_allocation_percent, Type::Float
  attribute :ram_allocation_percent, Type::Float
  attribute :cpu_utilization_percent, Type::Float
  attribute :ram_utilization_percent, Type::Float

  # collection :pods, :Pod

  def update(values)
    begin
      name = values.metadata.name
      hostname = scan('Hostname', 'address', values.status.addresses)
      binding.pry
    rescue
      nil
    end
  end

  def scan(type, field, array)
    array.each do |elem|
      return elem[field] if elem['type'] == type
    end
  end

  protected

  def after_save
    redis.call('EXPIRE', key, 90.days)
  end

  alias save! save
end
