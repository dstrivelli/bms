# frozen_string_literal: true

require File.expand_path 'spec_helper.rb', __dir__

require File.expand_path '../bms', __dir__

module RSpecMixin
  include Rack::Test::Methods
  def app
    Sinatra::Application
  end
end

RSpec.configure { |c| c.include RSpecMixin }

describe 'BMS Sinatra Application' do
  it 'should redirect / to /result/latest' do
    get '/'
    expect(last_response).to be_redirect
    follow_redirect!
    expect(last_request.url).to eql 'http://example.org/result/latest'
  end
end
