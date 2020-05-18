# frozen_string_literal: true

require 'ohm'
require 'ohm/contrib'

##
# Model to describe kubernetes deployments
class Deployment < Ohm::Model
  include Ohm::DataTypes

  reference :namespace, :Namespace

  attribute :name
  unique :name
  attribute :annotations, Type::Hash
  attribute :labels, Type::Hash
  attribute :images, Type::Array
  attribute :replicas, Type::Integer
  attribute :ready_replicas, Type::Integer

  def image
    # Assume first image in array is primary
    primary = images.first
    # Look through and make any local image the primary
    images.each do |img|
      primary = img if /^container-registry/.match? img
    end
    primary.split('/').last
  end

  def image_and_tag
    image.split(':', 2)
  end

  def to_report_hash
    hash = attributes.each_with_object({}) { |(k, _), h| h[k] = send(k) }
    hash[:primary_image] = image
    hash
  end

  # To allow FactoryBot to play nicely
  alias save! save
end
