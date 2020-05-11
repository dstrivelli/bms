# frozen_string_literal: true

require 'httparty'
require 'json'

require 'application_controller'
require 'nexus_repo'

# Controller for Labels
class LabelsController < ApplicationController
  before { @header = 'Docker Label Scanner' }

  # This has to go last because it's such a greedy match
  get '/:repo?' do |repo|
    @scripts = ['/js/labels.js']
    @repos = Settings&.nexus&.repos&.keys&.map(&:to_s)
    @repo = repo || @repos.first
    begin
      @images = DockerImage.find(repo: @repo).map(&:to_h)
    rescue CacheDataNotFoundError => e
      raise if settings.development?

      @error = e.message
    end
    slim :labels
  end
end
