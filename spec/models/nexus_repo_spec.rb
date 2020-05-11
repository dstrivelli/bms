# frozen_string_literal: true

require_relative '../spec_helper'

require 'nexus_repo'

describe NexusRepo do
  let(:first_repo)      { Settings&.nexus&.repos&.first }
  let(:first_repo_name) { first_repo[0].to_s }
  let(:first_repo_url)  { first_repo[1] }

  subject { NexusRepo.new(first_repo_name) }

  describe '.initialize' do
    let(:nexus) { NexusRepo.new(first_repo_name) }

    it 'sets the instance variable @repo' do
      expect(nexus.repo).to eql(first_repo_name)
    end

    it 'set the instance variable @url' do
      expect(nexus.url).to eql(first_repo_url)
    end
  end

  describe '.repos' do
    let(:result) { subject.repos }

    it 'returns an array' do
      expect(result).to be_instance_of Array
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
