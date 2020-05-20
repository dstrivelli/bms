# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/numeric/time'
require 'ohm'
require 'ohm/contrib'

##
# Model to describe Kubernetes nodes
class Node < Ohm::Model
  include Ohm::DataTypes

  attribute :name
  unique :name
  attribute :hostname
  attribute :ip
  attribute :annotations, Type::Hash
  attribute :labels, Type::Hash
  attribute :kernel_version
  attribute :kubelet_version
  attribute :conditions, Type::Array
  attribute :cpu_allocatable, Type::Float
  attribute :ram_allocatable, Type::Float
  attribute :cpu_utilized, Type::Float
  attribute :ram_utilized, Type::Float

  collection :pods, :Pod

  %w[cpu ram].each do |resource|
    %w[requests limits].each do |stat|
      define_method "#{resource}_#{stat}" do
        total = 0.0
        pods.each do |pod|
          total += pod.send("#{resource}_#{stat}")
        end
        total
      end
    end
  end

  def cpu_utilization_percent
    (cpu_utilized / cpu_allocatable * 100).round(2)
  end

  def ram_utilization_percent
    (ram_utilized / ram_allocatable * 100).round(2)
  end

  def cpu_allocation_percent
    (cpu_requests / cpu_allocatable * 100).round(2)
  end

  def ram_allocation_percent
    (ram_requests / ram_allocatable * 100).round(2)
  end

  def to_report_hash
    fields = %w[hostname kernel_version kubelet_version conditions cpu_allocation_percent ram_allocation_percent cpu_utilization_percent ram_utilization_percent]
    h = {}
    # Enumerate attributes
    fields.each do |k|
      h[k.to_sym] = send(k)
    end
    h # Return dat hash!
  end

  alias save! save
end
