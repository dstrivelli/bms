# frozen_string_literal: true

require 'httparty'
require 'logging'

{
  NoNexusReposConfigured: 'No Nexus repos configured in settings.yml',
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
  attr_reader :repo, :url

  def initialize(repo)
    raise 'Not a valid repo string.' unless %w[String Symbol].include?(repo.class.to_s)

    @logger = Logging::Logger.new(self)
    @repos = Settings&.nexus&.repos
    @repo = repo
    @url = @repos[repo.to_sym]
    @logger.debug "Initialized with connection to #{repo}"
  end

  def repos
    @repos.keys
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

  protected

  # All images with the tags and labels nested
  def images_with_tags
    @logger.debug "Fetching all images/tags/labels from #{@repo}..."
    images.each_with_object({}) do |img, list|
      list[img] = tags(image: img).each_with_object({}) do |tag, image_item|
        image_item[tag] = labels(image: img, tag: tag)
      end
    end
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
