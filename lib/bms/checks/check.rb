# frozen_string_literal: true

require 'bms'

module BMS
  module Checks
    # Generic class for checks
    class Check
      def initialize
        @logger = Logging.logger[self]
        @result = BMS::Result.new
      end

      def refresh
        @logger.info 'Refreshing data...'
      end

      def run
        refresh
        @result
      end

      def to_html
        @logger.debug 'to_html'
      end
    end
  end
end
