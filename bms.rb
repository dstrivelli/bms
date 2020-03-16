#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH << File.join(__dir__, 'lib')

require 'sinatra'
require 'config'
require 'json'
require 'mail'
require 'roadie'

require 'bms'
require 'bms/db'
require 'bms/helpers'

if development?
  # require 'sinatra/reloader'
  require 'pry-remote'
end

# Configure Sinatra
register Config
set :port, 5000

# Configure BMS
BMS::DB.load(Settings.db)

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
  html.add_css('button#email { display: none !important; max-height: 0 !important; overflow: hidden !important; }')

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
  rescue StandardError => e
    logger.error e.to_s
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
  if (@result = get_result(params[:timestamp]))
    @header = 'BMS Health Report'
    @caption = Time.at(@result[:timestamp]).strftime('%B %e, %Y %l:%M%P')
    slim :result
  else
    slim 'p No result found.'
  end
end

get '/results' do
  if (@results = results)
    slim :results
  else
    slim 'p No results in the database.'
  end
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
  health[:last_refresh] = BMS::DB.get_result(:latest)[:timestamp]
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
