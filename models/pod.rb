# frozen_string_literal: true

require 'ohm'
require 'ohm/contrib'

##
# Model to describe kubernetes pods
class Pod < Ohm::Model
  include Ohm::Callbacks
  include Ohm::DataTypes

  reference :node, :Node
  reference :namespace, :Namespace

  attribute :uid
  unique :uid
  attribute :name
  index :name
  attribute :annotations, Type::Hash
  attribute :labels, Type::Hash
  attribute :state
  index :state
  attribute :healthy, Type::Boolean
  index :healthy
  attribute :restarts, Type::Integer

  collection :containers, :Container

  # rubocop:disable Security/Eval
  %w[cpu ram].each do |resource|
    %w[requests limits].each do |stat|
      define_method "#{resource}_#{stat}" do
        total = 0.0
        containers.each do |container|
          total += eval("container.#{resource}_#{stat}", binding, __FILE__, __LINE__)
        end
        total
      end
    end
  end
  # rubocop:enable Security/Eval

  protected

  def before_save
    case state
    when 'Running', 'Succeeded'
      self.healthy = true
    else
      self.healthy = false
    end
  end

  # To allow FactoryBot to play nicely
  alias save! save
end
