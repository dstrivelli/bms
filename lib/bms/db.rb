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
    @filename = nil
    @logger = ::Logging.logger[self]

    def self.load(filename)
      @logger.debug "Loading #{filename}"
      if filename == @filename
        @logger.debug 'Not loading database that is already initialized.'
        return self
      end
      @filename = filename
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
      @filename = nil
    end

    def self.validate_db
      raise DatabaseNotInitializedError unless @db
    end

    def self.key?(key)
      validate_db
      @db.keys.include? key
    end

    def self.runs
      validate_db
      self[:runs].reverse
    end

    def self.[](key)
      validate_db
      @db.load
      @db[key]
    end
    singleton_class.send(:alias_method, :result, :[])

    def self.[]=(key, value)
      validate_db
      @db.set! key, value
    end
    singleton_class.send(:alias_method, :set, :[]=)

    def self.delete(key)
      @db.delete(key) if key?(key)
    end

    def self.save_result(result)
      validate_db
      @db.lock do
        @logger.debug { "Current @db[:runs].count = #{self[:runs].count}" }
        self[:runs] = self[:runs].append(result[:timestamp])
        @logger.debug { "After addition @db[:runs].count = #{self[:runs].count}" }
        self[result[:timestamp]] = result
        self[:latest] = result
        # Not entirely sure this flush is necessary but whatever
        @db.flush
      end
      result
    end
  end
end
