# frozen_string_literal: true

require 'factory_bot'
require 'ffaker'
require 'ohm'

require 'docker_image'
require 'docker_tag'

FactoryBot.define do
  factory :docker_image do
    repo { 'prod' }
    name { 'Image' } # TODO: generate this

    transient do
      tags_count { 5 }
    end

    after(:create) do |image, evaluator|
      create_list(:docker_tag, evaluator.tags_count, image: image)
    end
  end

  factory :docker_tag do
    association :image, factory: :docker_image
    name { FFaker::SemVer.next }
    labels do
      5.times.each_with_object({}) do |n, obj|
        obj["Label#{n}"] = %w[true false].sample
      end
    end
  end
end
