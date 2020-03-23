# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/hash/indifferent_access'
require 'application_controller'
require 'nexus_repo'
require 'httparty'
require 'json'

REMOTE_DOCKER = 'https://container-registry.prod8.bip.va.gov'

# Controller for Labels
class LabelsController < ApplicationController
  before { @header = 'Docker Label Scanner' }

  # This has to go last because it's such a greedy match
  get '/:repo?' do |repo|
    @scripts = ['/js/labels.js']
    @repos = NexusRepo.repos
    @repo = repo || @repos.first
    begin
      @images_with_tags = NexusRepo.new(@repo).images_with_tags(cache: :force)
    rescue CacheDataNotFoundError => e
      raise if settings.development?

      @error = e.message
    end
    slim :labels
  end
end
