#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH << File.join(__dir__, 'lib')

require 'sinatra'
require 'config'
require 'json'
require 'mail'
require 'roadie'

require 'bms/helpers'
require 'bms/result'

if development?
  require 'sinatra/reloader'
  require 'pry-remote'
end

register Config
set :port, 5000

get '/css/styles.css' do
  scss :styles
end

get '/' do
  redirect '/result/latest'
end

post '/email' do
  @result = if params[:id]
              get_result(params[:id])
            else
              get_result(:latest)
            end

  if params[:to]
    # TODO: Validate email is whitelisted
    to = params[:to]
  else
    to = Settings.email.distro.to
    cc = Settings.email.distro.cc || nil
  end
  subject = "[BMS] Snapshot Report - #{Time.at(@result[:timestamp]).strftime('%Y-%m-%d %I:%M%P')}"

  # Process html body
  html = Roadie::Document.new(slim(:result, layout: :layout_email))
  html.add_css(scss(:styles))

  begin
    Mail.new do
      from 'do_not_reply@va.gov'
      to to
      cc cc if defined?(cc)
      subject subject
      html_part do
        content_type 'text/html; charset=UTF-8'
        body html.transform
      end
      delivery_method :smtp, address: Settings.email.smtp.host, port: Settings.email.smtp.port
    end.deliver
  rescue StandardError
    'There was an error while attempting to send the email.'
  else
    'Email sent'
  end
end

post '/reload' do
  Process.kill :SIGHUP, worker_pid
  'Reloaded!'
rescue Errno::ESRCH
  'Error!'
end

get '/result/:timestamp' do
  # TODO: Validate input
  @result = get_result(params[:timestamp])
  @header = 'BMS Health Report'
  @caption = Time.at(@result[:timestamp]).to_s
  slim :result
end

get '/results' do
  @results = results
  slim :results
end

get '/health' do
  health = { status: 'green' }
  # Check worker status
  if worker_running?
    health[:worker] = 'running'
  else
    health[:status] = 'yellow'
    health[:worker] = 'stopped'
  end
  # Check database status
  health[:last_refresh] = get_result(:latest)[:timestamp]
  if health[:last_refresh]
    health[:database] = 'running'
  else
    health[:status] = 'red'
    health[:database] = 'errored'
  end
  case health[:status]
  when 'yellow'
    status 501
  when 'red'
    status 503
  end
  JSON.generate(health)
end
