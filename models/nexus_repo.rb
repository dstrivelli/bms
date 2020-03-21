# frozen_string_literal: true

require 'httparty'

# Model to handle Nexus queries
class NexusRepo
  REPOS = {
    prod: 'https://container-registry.prod8.bip.va.gov/',
    stage: 'https://container-registry.prod8.bip.va.gov/',
    dev: 'https://container-registry.dev8.bip.va.gov/'
  }.freeze

  def self.repos
    REPOS.keys.map(&:to_s)
  end

  def initialize(repo)
    raise 'No such Nexus repo defined.' unless REPOS.key? repo.to_sym

    BMS::DB.load('/tmp/bms.db')
    @name = repo
    @url = REPOS[repo.to_sym]
  end

  def images
    fetch(uri: '/v2/_catalog', value: :repositories)
  end

  def tags(image:)
    fetch(uri: "/v2/#{image}/tags/list", value: :tags)
  end

  def labels(image:, tag:)
    data = fetch(uri: "/v2/#{image}/manifests/#{tag}", value: :history)
    data.each_with_object({}) do |elem, labels|
      parsed = JSON.parse(elem[:v1Compatibility], { symbolize_names: true })
      begin
        parsed[:config][:Labels].each do |k, v|
          labels[k.to_s] = v
        end
      rescue NoMethodError
        nil
      end
    end
  end

  # All images with the tags and labels nested
  def images_with_tags(use_cache: true)
    if use_cache && BMS::DB.key?(db_key)
      # TODO: We should dry-validate these results
      return BMS::DB[db_key]
    end

    images.each_with_object({}) do |img, list|
      list[img] = tags(image: img).each_with_object({}) do |tag, image_item|
        image_item[tag] = labels(image: img, tag: tag)
      end
    end
  end

  private

  # The database key used to store cached results
  def db_key
    "#{@name}-labels"
  end

  # Call the Nexus api and return the result
  #
  # == Parameters:
  # uri::
  #   Path uri to query the repository with.
  #
  # keys::
  #   Array of keys to filter returned results
  #
  # value::
  #   Value used to filter down to a single result returned.
  #
  # == Returns:
  # A hash with the result filered by `keys:` or `value:` if given.
  def fetch(uri:, keys: nil, value: nil)
    url = URI.join(@url, uri)
    resp = HTTParty.get(url)
    json = JSON.parse(resp.body, { symbolize_names: true })
    json.slice(keys) if keys
    json[value] if value
  end
end
