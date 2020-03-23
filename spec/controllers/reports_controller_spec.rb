# frozen_string_literal: true

require_relative '../spec_helper.rb'
require 'mail'

require 'reports_controller'

describe ReportsController do
  let(:app) { ReportsController.new }

  before { load_db }

  context 'get /' do
    let(:response) { get '/' }

    it 'returns redirects to /reports/latest' do
      expect(response).to redirect_to 'http://example.org/reports/latest'
    end
  end

  context 'get /email' do
    let(:params) do
      {
        'id' => 'latest',
        'to' => 'admin@approved.com',
        'cc' => 'corporate.suit@approved.com'
      }
    end

    context 'denies me if' do
      context 'using unapproved email address' do
        context 'in to line' do
          let(:unapproved_params) { params.merge({ 'to' => 'hakz0r@denied.net' }) }
          let(:response) { post '/email', unapproved_params }

          it 'returns a 401' do
            expect(response.status).to eql 401
          end

          it 'tells me why' do
            expect(response.body).to include(unapproved_params['to'])
          end
        end

        context 'in cc line' do
          let(:unapproved_cc_params) { { 'cc' => 'hakz0r@denied.net' } }
          let(:response) { post '/email', params.merge(unapproved_cc_params) }

          it 'returns a 401' do
            expect(response.status).to eql 401
          end

          it 'tells me why' do
            expect(response.body).to include(unapproved_cc_params['cc'])
          end
        end
      end
    end

    context 'creates an email' do
      before do
        Mail::TestMailer.deliveries.clear
        post '/email', params
      end

      it 'at all' do
        is_expected.to have_sent_email
      end

      it 'that has the correct from line' do
        is_expected.to have_sent_email.from('do_not_reply@va.gov')
      end

      it 'that has the correct to line' do
        is_expected.to have_sent_email.to(params['to'])
      end

      it 'that has the correct cc line' do
        is_expected.to have_sent_email.cc(params['cc'])
      end

      it 'that has the correct subject line' do
        is_expected.to have_sent_email.matching_subject(/^\[BMS\]/)
      end

      it 'contains the report in the body' do
        is_expected.to have_sent_email.matching_body('BMS Health Report for')
      end
    end
  end
end
