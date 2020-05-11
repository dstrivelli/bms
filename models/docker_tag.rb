# frozen_string_literal: true

require 'ohm'
require 'ohm/contrib'

##
# Model to describe tags of docker images in docker repository
class DockerTag < Ohm::Model
  include Ohm::DataTypes

  reference :image, :DockerImage

  attribute :name
  attribute :labels, Type::Hash
  index :name

  # To mock this with FactoryBot
  alias save! save
end
