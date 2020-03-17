# frozen_string_literal: true

require 'ostruct'

module BMS
  # Result class to hold results in extended OpenStruct
  class Result < OpenStruct
    def load(path)
      @table = YAML.safe_load(File.read(path))
    end
  end
end
