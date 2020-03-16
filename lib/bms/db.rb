# frozen_string_literal: true

require 'bms/result'
require 'daybreak'
require 'singleton'

module BMS
  class DatabaseAlreadyInitializedError < StandardError
  end

  class DatabaseNotInitilizedError < StandardError
  end

  class DB
    include Singleton

    def self.load(filename)
      @db.close if (defined?(@db) && @db)
      @db = Daybreak::DB.new(filename)
      at_exit do
        @db.close if (defined?(@db) && @db)
      end
      # Init :runs if empty db
      @db[:runs] = [] unless @db[:runs].is_a? Array

      # Return instance for method chaining
      self
    end

    def self.close
      self.validate_db
      @db.close
      @db = nil
    end

    def self.validate_db
      raise DatabaseNotInitializedError unless (defined?(@db) && @db)
    end

    def self.get_runs
      self.validate_db
      @db[:runs].reverse
    end

    def self.get_result(timestamp)
      self.validate_db
      @db[timestamp]
    end

    def self.[](key)
      self.validate_db
      @db[key]
    end

    def self.[]=(key, value)
      self.validate_db
      @db.set! key, value
    end

    def self.save_result(result)
      self.validate_db
      @db.lock do
        #@log.debug { "Current @db[:runs].count = #{@db[:runs].count}" }
        self[:runs].append(result[:timestamp])
        #@log.debug { "After addition @db[:runs].count = #{@db[:runs].count}" }
        self[result[:timestamp]] = result
        self[:latest] = result[:timestamp]
        # Not entirely sure this flush is necessary but whatever
        @db.flush
      end
      result
    end
  end
end
