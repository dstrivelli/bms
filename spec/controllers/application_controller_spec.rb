# frozen_string_literal: true

require_relative '../spec_helper.rb'

require 'application_controller'

describe ApplicationController do
  let(:app) { ApplicationController.new }

  context 'GET /' do
    let(:response) { get '/' }

    it 'redirects to /dashboard' do
      expect(response).to redirect_to 'http://example.org/dashboard'
    end
  end

  context 'GET /css/styles.css' do
    let(:response) { get '/css/styles.css' }

    it 'returns status 200' do
      expect(response.status).to eql 200
    end
  end

  context 'GET /notarealurl' do
    let(:response) { get '/notarealurl' }

    it 'returns status 404' do
      expect(response.status).to eql 404
    end

    it 'says something funny' do
      expect(response.body).to include("I don't know what you want.")
    end
  end
end
