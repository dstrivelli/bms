# frozen_string_literal: true

require_relative '../spec_helper.rb'
require 'email_helpers'

describe EmailHelpers do
  let(:test_class) { Class.new.extend(EmailHelpers) }
  let(:whitelists) { ['^.*@approved\.com'] }
  let(:approved_email) { 'corporate.suit@approved.com' }
  let(:unapproved_email) { 'l33t.haxz0r@denied.com' }

  context '.validate_emails' do
    it 'accepts single string' do
      expect { test_class.validate_emails(approved_email, whitelists: whitelists) }.to_not raise_error
    end
    it 'accepts array of addresses' do
      expect { test_class.validate_emails([approved_email], whitelists: whitelists) }.to_not raise_error
    end

    it 'denies everything if no whitelist given' do
      expect(test_class.validate_emails(approved_email)[:approved]).to eql false
    end

    context 'with unapproved email' do
      let(:response) { test_class.validate_emails(unapproved_email, whitelists: whitelists) }

      it 'returns :approved == false' do
        expect(response[:approved]).to eql false
      end

      it 'lists the approved email address' do
        expect((response[:unapproved].include? unapproved_email)).to eql true
      end
    end

    context 'with approved email' do
      let(:response) { test_class.validate_emails(approved_email, whitelists: whitelists) }

      it 'returns :approved as true' do
        expect(response[:approved]).to eql true
      end

      it 'returns an empty :unapproved' do
        expect(response[:unapproved]).to eql []
      end

      it 'has an empty :reason' do
        expect(response[:reason]).to be_empty
      end
    end
  end

  context 'with invalid whitelists' do
    let(:response) { test_class.validate_emails(approved_email, whitelists: ['*']) }

    it 'does not approve the check' do
      expect(response[:approved]).to eql false
    end
  end
end
