# frozen_string_literal: true

require 'bms'
require 'json'
require 'mail'
require 'roadie'

# Controller to handle health reports
class ReportsController < ApplicationController
  helpers DisplayHelpers

  get '/' do
    redirect '/reports/latest'
  end

  post '/email' do
    @report = if params[:id]
                BMS::DB[params[:id]]
              else
                BMS::DB[:latest]
              end
    if params[:to]
      # TODO: Validate email is whitelisted
      to = params[:to]
    else
      to = Settings.email.distro.to
      cc = Settings.email.distro.cc || nil
    end
    subject = "[BMS] Snapshot Report - #{Time.at(@report[:timestamp]).strftime('%Y-%m-%d %I:%M%P')}"

    # Process html body
    html = Roadie::Document.new(slim(:report, layout: :layout_email))
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

  get %r{/([1-9][0-9]*|latest)} do
    timestamp = params['captures'].first
    # TODO: Validate input
    if (@report = BMS::DB.result(timestamp))
      @header = 'BMS Health Report'
      @caption = Time.at(@report.timestamp).strftime('%B %e, %Y %l:%M%P')
      slim :report
    else
      slim 'p No result found.'
    end
  end

  get '/list' do
    if (@reports = BMS::DB.runs)
      slim :reports
    else
      slim 'p No reports in the database.'
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
    health[:last_refresh] = BMS::DB.result(:latest)[:timestamp]
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
end
