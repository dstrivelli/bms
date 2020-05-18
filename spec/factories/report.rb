# frozen_string_literal: true

require 'factory_bot'
require 'ffaker'
require 'ohm'

require 'report'
require 'health_check'

FactoryBot.define do
  factory :report do
    transient do
      nodes_count { 5 }
      health_checks_count { 5 }
    end

    timestamp { Time.now.to_i }
    # TODO: Move this to it's own factory
    nodes do
      node_list = []
      nodes_count.times do
        node_list << {
          hostname: FFaker::InternetSE.domain_word,
          kernel_version: '3.10.0-1127.el7.x86_64',
          kubelet_version: 'v1.12.7',
          conditions: ['Ready'],
          cpu_allocation_percent: rand(100),
          ram_allocation_percent: rand(100),
          cpu_utilization_percent: rand(100),
          ram_utilization_percent: rand(100)
        }
      end
      node_list
    end
    restarts do
      [
        {
          namespace: 'namespace1',
          name: 'pod1',
          value: 1
        }, {
          namespace: 'namespace2',
          name: 'pod2',
          value: 2
        }
      ]
    end
    unhealthy_pods { [] }
    # TODO: Move this to it's own factory
    health_checks do
      [
        {
          name: FFaker::InternetSE.slug,
          uri: FFaker::InternetSE.uri('https'),
          result: '200 OK',
          details: FFaker::HipsterIpsum.paragraph
        }
      ]
    end

    # after(:create) do |report, evaluator|
    #   create_list(:health_check, evaluator.health_checks_count)
    # end
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
