# frozen_string_literal: true

require 'httparty'
require 'json'
require 'sinatra/json'

require 'application_controller'
require 'nexus_repo'

# Controller for Labels
class LabelsController < ApplicationController
  before do
    heading 'Docker Label Scanner'
    js 'labels.js'
    @repos = {
      'prod8' => 'https://container-registry.prod8.bip.va.gov/',
      'stage8' => 'https://container-registry.stage8.bip.va.gov/'
    }
  end

  get '/' do
    slim :labels
  end

  get '/images', provides: :json do
    param :repo, String, required: true, in: @repos.keys

    resp = HTTParty.get(URI.join(@repos[params[:repo]], '/v2/_catalog'))
    json = JSON.parse(resp.body, { symbolize_names: true })
    images = json[:repositories]

    json images
  end

  get '/tags', provides: :json do
    param :repo, String, required: true, in: @repos.keys
    param :image, String, required: true

    resp = HTTParty.get(URI.join(@repos[params[:repo]], "/v2/#{params[:image]}/tags/list"))
    json = JSON.parse(resp.body, { symbolize_names: true })
    tags = json[:tags]

    json tags
  end

  get '/labels', provides: :json do
    param :repo, String, required: true, in: @repos.keys
    param :image, String, required: true
    param :tag, String, required: true

    resp = HTTParty.get(URI.join(@repos[params[:repo]], "/v2/#{params[:image]}/manifests/#{params[:tag]}"))
    json = JSON.parse(resp.body, { symbolize_names: true })
    labels = {}
    json[:history].each_with_object(labels) do |elem, obj|
      parsed = JSON.parse(elem[:v1Compatibility], { symbolize_names: true })
      begin
        parsed[:config][:Labels].each do |k, v|
          obj[k.to_s] = v
        end
      rescue NoMethodError
        nil
      end
    end

    json labels
  end
end
