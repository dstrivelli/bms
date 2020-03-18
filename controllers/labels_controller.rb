# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'
require 'httparty'
require 'json'

REMOTE_DOCKER = 'https://container-registry.prod8.bip.va.gov'

# Controller for Labels
class LabelsController < ApplicationController
  get '/' do
    @images = NexusRepo.images
    @image = nil
    @tag = nil
    slim :labels
  end

  get '/tags' do
    JSON.generate NexusRepo.tags(params['image'])
  end

  get '/labels' do
    @labels = NexusRepo.labels(params['image'], params['tag'])
    slim :label_list, layout: nil
  end

  post '/lookup' do
    image = params['image']
    tag = params['tag']
    @labels = []
    # TODO: Validate this and url encode
    url = URI.join(REMOTE_DOCKER, "/v2/#{image}/manifests/#{tag}")
    response = HTTParty.get(url)
    json = JSON.parse(response.body, { symbolize_names: true })
    json.slice!(:name, :tag, :history)
    json[:history].each do |h|
      parsed = JSON.parse(h[:v1Compatibility]).with_indifferent_access
      if (labels = parsed&.config&.Labels)
        @labels.append(labels)
      end
    end
    slim :label_output
  end
end
