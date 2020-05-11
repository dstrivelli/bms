# frozen_string_literal: true

require 'ohm'

##
# Model to describe errors during report run
# TODO: Implement this
class Error < Ohm::Model
  reference :report, :Report

  attribute :message
  attribute :error
end
