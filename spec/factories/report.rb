# frozen_string_literal: true

require 'factory_bot'
require 'ffaker'
require 'ohm'

require 'report'
require 'health_check'

FactoryBot.define do
  factory :report do
    timestamp { Time.now.to_i }
    complete { true }

    transient do
      nodes_count { 5 }
      health_checks_count { 5 }
    end

    after(:create) do |report, evaluator|
      create_list(:health_check, evaluator.health_checks_count, report: report)
    end
  end

  factory :health_check, class: 'HealthCheck' do
    transient do
      response { 200 }
    end

    report
    name   { FFaker::Internet.user_name }
    uri    { FFaker::Internet.http_url }
    result { '200 OK' }

    before(:create) do |health_check, evaluator|
      health_check.result = case evaluator.response
                            when 200
                              '200 OK'
                            when 404
                              '404 NOT FOUND'
                            when 500
                              '500 ERROR'
                            end
    end
  end
end
