# frozen_string_literal: true

require 'active_support/core_ext/hash/except'
require 'ohm'
require 'ohm/contrib'

##
# Model to describe an image in a docker repository
class DockerImage < Ohm::Model
  include Ohm::Callbacks

  attribute :repo
  index :repo
  attribute :name
  index :name

  collection :tags, :DockerTag, :image

  def to_h
    h = {}
    h[:name] = name
    h[:tags] = tags.each_with_object({}) do |tag, obj|
      obj[tag.name] = tag.labels
    end
    to_hash.merge(h)
  end

  def before_delete
    tags.each(&:delete)
  end

  # To mock this with FactoryBot
  alias save! save
end
