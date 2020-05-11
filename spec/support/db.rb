# frozen_string_literal: true

require 'ohm'

# Mixin module to include database function in specs
module TestDatabase
  # Initialize the database
  Ohm.redis = Redic.new('redis://127.0.0.1:6379/2')

  def reset_db
    Ohm.flush
  end
end
