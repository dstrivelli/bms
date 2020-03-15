# frozen_string_literal: true

require File.expand_path 'spec_helper.rb', __dir__

describe 'BMS Sinatra Application' do
  it 'should redirect home to /result/latest' do
    get '/'
    expect(last_response).to redirect_to '/result/latest'
  end
end
