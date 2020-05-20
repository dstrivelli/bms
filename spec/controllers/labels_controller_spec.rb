# frozen_string_literal: true

require_relative '../spec_helper.rb'

require 'labels_controller'
require 'nexus_repo'

describe LabelsController do
  let(:app) { LabelsController.new }

  before(:all) do
    reset_db
    @images = create_list(:docker_image, 5)
  end

  context 'GET /' do
    let(:repos) { Settings&.nexus&.repos }
    let(:response) { get '/' }

    it 'does not raise an error' do
      expect { response }.to_not raise_error
    end

    it 'returns status 200' do
      expect(response.status).to eql 200
    end

    it 'displays the header' do
      expect(response.body).to have_tag('h1', text: 'Docker Label Scanner')
    end

    it 'assumes first repo if none passed'
    it 'displays the repos in a btn-group' do
      expect(response.body).to have_tag('div', with: { class: 'btn-group' }) do
        repos.each do |repo_name, _url|
          with_tag 'a', with: { class: 'btn', href: "/labels/#{repo_name}" }, text: repo_name
        end
      end
    end

    it 'activates the current repo btn' do
      expect(response.body).to have_tag 'a', with: { class: %w[btn active] }, text: repos.first[0].to_s
    end

    it 'displays the images'
    it 'displays the tags'
  end
end