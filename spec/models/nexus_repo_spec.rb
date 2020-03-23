# frozen_string_literal: true

require_relative '../spec_helper'

require 'nexus_repo'

describe NexusRepo do
  let(:first_repo)      { NexusRepo::REPOS.first }
  let(:first_repo_name) { first_repo[0].to_s }
  let(:first_repo_url)  { first_repo[1] }

  describe 'self.repos' do
    it 'returns an array' do
      expect(NexusRepo.repos).to be_instance_of Array
    end
  end

  describe '.initialize' do
    context 'with no repo passed' do
      let(:nexus) { NexusRepo.new }

      it 'defaults to first repo if none given' do
        expect(nexus.repo).to eql(first_repo_name)
      end
    end

    context 'with a valid repo' do
      let(:sample) do
        s = NexusRepo::REPOS.keys.sample
        NexusRepo::REPOS.select { |k, _v| k == s }
      end
      let(:sample_name) { sample.first[0] }
      let(:sample_url) { sample.first[1] }
      let(:nexus) { NexusRepo.new(sample_name) }

      it 'sets the instance variable @repo' do
        expect(nexus.repo).to eql(sample_name)
      end

      it 'set the instance vairable @url' do
        expect(nexus.url).to eql(sample_url)
      end
    end
  end

  describe '.images', :vcr do
    let(:result) { subject.images }

    it 'returns an array' do
      expect(result).to be_instance_of Array
    end
  end

  describe '.tags', :vcr do
    context 'with good data' do
      let(:image) { subject.images.first }
      let(:result) { subject.tags(image: image) }

      it 'returns an array' do
        expect(result).to be_instance_of Array
      end
    end

    context 'raises an error when' do
      it 'no image is passed' do
        expect { subject.tags }.to raise_error(ArgumentError)
      end

      xit 'image does not exist' do
        expect { subject.tags(image: 'NotARealImage') }.to raise_error(ImageDoesNotExistError)
      end
    end
  end

  describe '.labels', :vcr do
    let(:image) { subject.images.first }
    let(:tag) { subject.tags(image: image).first }
    let(:result) { subject.labels(image: image, tag: tag) }

    it 'returns a hash' do
      expect(result).to be_instance_of Hash
    end

    context 'raises an error when' do
      it 'no image is passed' do
        expect { subject.labels }.to raise_error(ArgumentError)
      end

      it 'raises an error if no tag is passed' do
        expect { subject.labels(image: image) }.to raise_error(ArgumentError)
      end
    end
  end
end
