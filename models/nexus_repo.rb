# frozen_string_literal: true

require 'httparty'
require 'logging'

{
  CacheDataNotFound: 'No cached data found.',
  ImageDoesNotExist: 'The images does not exist in the repository',
  TagDoesNotExist: 'The image tag does not exist in the repository'
}.each do |error_name, error_msg|
  eval <<-EVAL_END # rubocop:disable all
    #{error_name}Error = Class.new(StandardError) do
      def initialize(msg='#{error_msg}')
        super
      end
    end
  EVAL_END
end

# Model to handle Nexus queries
class NexusRepo
  REPOS = {
    prod: 'https://container-registry.prod8.bip.va.gov/',
    stage: 'https://container-registry.stage8.bip.va.gov/',
    dev: 'https://container-registry.dev8.bip.va.gov/'
  }.freeze

  def self.repos
    REPOS.keys.map(&:to_s)
  end

  attr_reader :repo, :url

  def initialize(repo = nil)
    repo ||= REPOS.keys.first.to_s
    raise 'No such Nexus repo defined.' unless REPOS.key? repo.to_sym

    BMS::DB.load('/tmp/bms.db')
    @logger = Logging::Logger.new(self)
    @repo = repo
    @url = REPOS[repo.to_sym]
    @logger.debug "Initialized with connection to #{repo}"
  end

  def images
    @logger.debug "Fetching images from #{@repo}..."
    fetch(uri: '/v2/_catalog', value: :repositories)
  end

  def tags(image:)
    @logger.debug "Fetching tags for #{image} from #{@repo}"
    fetch(uri: "/v2/#{image}/tags/list", value: :tags)
  end

  def labels(image:, tag:)
    @logger.debug "Fetching labels for #{image}:#{tag} from #{@repo}"
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
  def images_with_tags(cache: :use)
    @logger.debug "Fetching all images/tags/labels from #{@repo}..."
    case cache
    when :use
      if BMS::DB.key?(db_key)
        @logger.debug 'Returning cached results.'
        return BMS::DB[db_key]
      else
        @logger.debug 'No cached results found.'
      end
    when :force
      if BMS::DB.key?(db_key)
        @logger.debug 'Returning cached results.'
        return BMS::DB[db_key]
      else
        @logger.debug 'No cached results found. Raising error because :forced.'
        raise CacheDataNotFoundError
      end
    when :expire
      @logger.debug 'Expiring cached results from database.'
      BMS::DB.delete(db_key)
    end

    @logger.debug 'Pulling data from Nexus repository'
    images.each_with_object({}) do |img, list|
      list[img] = tags(image: img).each_with_object({}) do |tag, image_item|
        image_item[tag] = labels(image: img, tag: tag)
      end
    end
  end

  private

  # The database key used to store cached results
  def db_key
    "#{@repo}-labels"
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
