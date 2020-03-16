# frozen_string_literal: true

require File.expand_path 'spec_helper.rb', __dir__

describe 'BMS Sinatra Application' do
  it 'should redirect / to /result/latest' do
    get '/'
    expect(last_response).to be_redirect
    follow_redirect!
    expect(last_request.url).to eql 'http://example.org/result/latest'
  end
end
