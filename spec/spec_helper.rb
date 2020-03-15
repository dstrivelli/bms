# frozen_string_literal: true

require 'rack/test'
require 'rspec'

ENV['APP_ENV'] = 'test'
ENV['RACK_ENV'] = 'test'

require File.expand_path '../bms', __dir__

module RspecMixin
  include Rack::Test::Methods
  def app
    Sinatra::Application
  end
end

Rspec.configure { |c| c.include RspecMixin }
