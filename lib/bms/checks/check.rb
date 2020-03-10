require 'bms'
require 'logger'

module BMS
  module Checks
    class Check
      attr_accessor :log

      def initialize(args = {})
        @result = BMS::Result.new
        # Logger setup
        if args[:logger]
          @log = args[:logger]
        else
          @log = ::Logger.new(STDOUT)
          @log.level = Settings.log_level ? Settings.log_level : :warn
        end
      end

      def refresh
        @log 'Refreshing data...'
      end

      def run
        refresh
        @result
      end

      def to_html
      end
    end
  end
end
