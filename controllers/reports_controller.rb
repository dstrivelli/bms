# frozen_string_literal: true

require 'bms'
require 'json'
require 'mail'
require 'roadie'

require 'application_controller'
require 'display_helpers'
require 'email_helpers'

# Controller to handle health reports
class ReportsController < ApplicationController
  helpers EmailHelpers

  get '/' do
    redirect '/reports/latest'
  end

  post '/email' do
    params[:id] = params[:id].to_sym if params[:id].is_a? String

    # Get email settings
    settings = Settings&.email || Hash.new(nil)
    whitelists = Settings&.email&.approved || []

    to = settings&.distro&.to || []
    cc = settings&.distro&.cc || []

    to = params[:to] if params[:to]
    cc = params[:cc] if params[:cc]

    to = [to] if to.is_a? String
    cc = [cc] if cc.is_a? String

    # Validate if email addresses are approved
    email_approvals = validate_emails(to + cc, whitelists: whitelists)
    unless email_approvals[:approved]
      status 401
      return slim :_alert, locals: { type: :error, msg: email_approvals[:reason] }, layout: nil
    end

    @report = if params[:id]
                BMS::DB[params[:id]]
              else
                BMS::DB[:latest]
              end

    unless @report
      status 401
      return slim :_alert, locals: { type: :error, msg: 'Email failed. Invalid report id.' }, layout: nil
    end

    subject = "[BMS] Snapshot Report - #{display_time(@report[:timestamp])}"

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
      end.deliver
    rescue StandardError
      status 500
      slim :_alert, locals: { type: :error, msg: 'There was an error while attempting to send the email.' }, layout: nil
    else
      slim :_alert, locals: { type: :notice, msg: 'Email sent' }, layout: nil
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
      @caption = display_time(@report.timestamp)
      slim :report_with_email_button
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
