# frozen_string_literal: true

require 'fileutils'
require_relative '../spec_helper'

require 'bms/db'

# Since this is a very statefule class, I have decided to test behavior in the
# different states of the class instead of the methods.

RSpec.shared_examples 'accessor' do |param|
  it 'should not throw an error' do
  end
end

# Spec to test the BMS::DB
module BMS
  describe DB do
    let(:db_file)        { File.expand_path('../artifacts/bms.db', __dir__) }
    let(:notinitialized) { DatabaseNotInitializedError }

    it 'should act like Singleton' do
      expect{DB.new}.to raise_error(NoMethodError)
    end

    context 'with unintialized database' do
      before(:each) { DB.close } # In case we run tests out of order
      after(:each) { DB.close } # Clean up

      describe '.load()' do
        it 'should return a valid DB' do
          expect(DB.load(db_file)).to eql(BMS::DB)
        end
      end

      describe '.close' do
        it 'should not raise an error' do
          expect{DB.close}.to_not raise_error
        end
      end

      describe '.validate_db' do
        it 'should raise an error' do
          expect{DB.validate_db}.to raise_error(notinitialized)
        end
      end

      describe '.runs' do
        it 'should raise an error' do
          expect{DB.runs}.to raise_error(notinitialized)
        end
      end

      describe '.[]' do
        it 'should raise an error' do
          expect{DB[:latest]}.to raise_error(notinitialized)
        end
      end

      describe '.result()' do
        it 'should raise an error' do
          expect{DB.result(:latest)}.to raise_error(notinitialized)
        end
      end

      describe '.[]=' do
        it 'should raise an error' do
          expect{DB[:key] = :value}.to raise_error(notinitialized)
        end
      end

      describe '.set' do
        it 'should raise an error' do
          expect{DB.set(:key, :value)}.to raise_error(notinitialized)
        end
      end

      describe '.[]=' do
        it 'should raise an error' do
          expect{DB[:key] = :value}.to raise_error(notinitialized)
        end
      end

      describe '.save_result()' do
        it 'should raise an error' do
          expect{DB.save_result(:value)}.to raise_error(notinitialized)
        end
      end
    end # invalid db

    context 'with blank db' do
      let(:blank_db) { File.expand_path('../artifacts/blank.db', __dir__) }

      before do
        FileUtils.rm_f(blank_db) if File.exists?(blank_db)
        DB.load(blank_db)
      end

      after do
        DB.close
        FileUtils.rm_f(blank_db) if File.exists?(blank_db)
      end
       
      describe '.load' do
        it 'should return a valid BMS:DB' do
          expect(DB.load(db_file)).to eql(BMS::DB)
        end

        it 'should initialize :runs to blank array' do
          expect(DB[:runs]).to eql([])
        end
      end
    end # blank db

    context 'with valid db' do
      let(:test_file)    { File.expand_path('../artifacts/test.db', __dir__) }
      let(:test_db)      { Daybreak::DB.new(test_file) }
      let(:valid_result) { DB[DB.runs.first] }

      before { FileUtils.cp(db_file, test_file) }
      after do
        FileUtils.rm(test_file) if File.exists?(test_file)
        DB.close
      end

      before(:each) { DB.load(test_file) }
      after(:each) do
        DB.close
        test_db&.close
      end

      describe '.load' do
        it 'should not throw an error' do
          expect{DB.load(db_file)}.to_not raise_error
        end
      end
      
      describe '.close' do
        it 'should not throw an error' do
          expect{DB.close}.to_not raise_error
        end
      end

      describe 'validate_db' do
        it 'should not throw an error' do
          expect{DB.validate_db}.to_not raise_error
        end
      end

      describe '.runs' do
        it 'returns array' do
          expect(DB.runs).to be_instance_of(Array)
        end

        it 'returns the correct value' do
          expect(DB.runs).to eql(test_db[:runs].reverse)
        end
      end

      describe '.[]()' do
        it 'returns the correct value' do
          expect(DB[valid_result[:timestamp]]).to eql(valid_result)
        end
      end

      describe '.result()' do
        it 'returns the correct value' do
          expect(DB.result(valid_result[:timestamp])).to eql(valid_result)
        end
      end

      describe '.[]=' do
        it 'stores the correct value' do
          expect(DB[:test] = :test).to eql(test_db[:test])
        end
      end

      describe '.set()' do
        it 'stores the correct value' do
          expect(DB.result(valid_result[:timestamp])).to eql(valid_result)
        end
      end

      describe '.save_result()' do
        let(:timestamp) { Time.now.to_i }
        let(:result) { { timestamp: timestamp } }

        before { DB.save_result(result) }

        it 'stores the result' do
          expect(test_db[valid_result[:timestamp]]).to eql(valid_result)
        end

        it 'adds the result to :runs' do
          expect(test_db[:runs].last).to eql(valid_result[:timestamp])
        end

        it 'stores the latest result to :latest' do
          expect(test_db[:latest]).to eql(valid_result)
        end
      end
    end # valid db
  end
end
