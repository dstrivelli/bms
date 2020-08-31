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
  reference :deployment, :Deployment

  attribute :uid
  unique :uid
  attribute :name
  index :name
  attribute :created_at, Type::Time
  attribute :annotations, Type::Hash
  attribute :labels, Type::Hash
  attribute :state
  index :state
  attribute :ready_string
  attribute :healthy, Type::Boolean
  index :healthy
  attribute :orphan, Type::Boolean
  index :orphan
  attribute :restarts, Type::Integer
  attribute :scheduled, Type::Boolean
  attribute :scheduled_at, Type::Time
  attribute :scheduled_message
  attribute :initialized, Type::Boolean
  attribute :initialized_at, Type::Time
  attribute :initialized_message
  attribute :ready, Type::Boolean
  attribute :ready_at, Type::Time
  attribute :ready_message
  attribute :containers_ready, Type::Boolean
  attribute :containers_ready_at, Type::Time
  attribute :containers_ready_message

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

  def images(sep: ', ')
    imgs = []
    containers.each { |container| imgs << container.image.rpartition('/').last }
    imgs.join(sep)
  end

  def status_message
    case # rubocop:disable Style/EmptyCaseCondition
    when ready
      'Ready'
    when initialized
      'Initialized'
    when scheduled
      'Scheduled'
    else
      'Unknown'
    end
  end

  def to_hash
    result = super.merge(attributes.each_with_object({}) { |(k, _), h| h[k] = send(k) })
    result[:namespace] = namespace.name
    result
  end

  def errors
    rtn = []
    # Check pod status
    rtn << "Pod is NOT ready. Reason: #{ready_message}" unless ready
  end

  protected

  def before_save
    self.orphan = deployment.nil?
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
