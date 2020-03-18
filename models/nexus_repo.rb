# frozen_string_literal: true

require 'json'
require 'httparty'

DOCKER_REPO = 'https://container-registry.prod8.bip.va.gov/'

# Model to handle Nexus queries
class NexusRepo
  def self.images
    fetch('/v2/_catalog', value: :repositories)
  end

  def self.tags(image)
    fetch("/v2/#{image}/tags/list", value: :tags)
  end

  def self.labels(image, tag)
    data = fetch("/v2/#{image}/manifests/#{tag}", value: :history)
    labels = {}
    data.each do |elem|
      parsed = JSON.parse(elem[:v1Compatibility], { symbolize_names: true })
      begin
        parsed[:config][:Labels].each do |k, v|
          labels[k.to_s] = v
        end
      rescue NoMethodError
        nil
      end
    end
    labels
  end

  def self.fetch(uri, keys: nil, value: nil)
    url = URI.join(DOCKER_REPO, uri)
    resp = HTTParty.get(url)
    json = JSON.parse(resp.body, { symbolize_names: true })
    json.slice(keys) if keys
    json[value]
  end

  private_class_method :fetch
end
