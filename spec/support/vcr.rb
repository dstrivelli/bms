# frozen_string_literal: true

require 'webmock/rspec'
require 'vcr'

# Configure VCR to record http requests
VCR.configure do |c|
  c.cassette_library_dir = File.expand_path '../fixtures/cassettes', __dir__
  c.hook_into :webmock
  c.default_cassette_options = { record: :new_episodes }
  c.configure_rspec_metadata!
end

# Disable external http requests
WebMock.disable_net_connect!(allow_localhost: true)
