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

  # rubocop:disable Security/Eval
  %w[cpu ram].each do |resource|
    %w[requests limits].each do |stat|
      define_method "#{resource}_#{stat}" do
        total = 0.0
        pods.each do |pod|
          total += eval("pod.#{resource}_#{stat}", binding, __FILE__, __LINE__)
        end
        total
      end
    end
  end

  %w[cpu ram].each do |resource|
    define_method "#{resource}_utilization_percent" do
      eval("(#{resource}_utilized / #{resource}_allocatable * 100).round(2)", binding, __FILE__, __LINE__)
    end
  end
  # rubocop:enable Security/Eval

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
      h[k.to_sym] = eval("self.#{k}", binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
    end
    h # Return dat hash!
  end

  alias save! save
end
