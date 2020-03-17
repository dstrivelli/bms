# frozen_string_literal: true

require 'bms/result'
require 'daybreak'
require 'logging'
require 'singleton'

module BMS
  class DatabaseNotInitializedError < StandardError
  end

  # Singleton class to handle database interactions
  class DB
    include Singleton

    attr_reader :db

    @db = nil
    @logger = ::Logging.logger[self]

    def self.load(filename)
      @logger.debug "Loading #{filename}"
      if @db
        @logger.debug 'Previous @db loaded. Closing.'
        @db.close
      end
      @db = Daybreak::DB.new(filename)
      at_exit do
        @db&.close
      end
      # Init :runs if empty db
      @db[:runs] = [] unless @db[:runs].is_a? Array

      # Return instance for method chaining
      self
    end

    def self.close
      @db&.close
      @db = nil
    end

    def self.validate_db
      raise DatabaseNotInitializedError unless @db
    end

    def self.runs
      validate_db
      @db[:runs].reverse
    end

    def self.[](key)
      validate_db
      @db[key]
    end
    self.singleton_class.send(:alias_method, :result, :[])

    def self.[]=(key, value)
      validate_db
      @db.set! key, value
    end
    self.singleton_class.send(:alias_method, :set, :[]=)

    def self.save_result(result)
      validate_db
      @db.lock do
        @logger.debug { "Current @db[:runs].count = #{@db[:runs].count}" }
        self[:runs] = self[:runs].append(result[:timestamp])
        @logger.debug { "After addition @db[:runs].count = #{@db[:runs].count}" }
        self[result[:timestamp]] = result
        self[:latest] = result
        # Not entirely sure this flush is necessary but whatever
        @db.flush
      end
      result
    end
  end
end
