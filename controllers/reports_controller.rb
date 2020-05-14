# frozen_string_literal: true

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
    # Validation
    params do
      required('id')
      optional('to').value(:string)
      optional('cc').value(:string)
    end

    # Get email settings
    email_settings = Settings&.email || Hash.new(nil)
    whitelists = Settings&.email&.approved || []

    to = email_settings&.distro&.to || []
    cc = email_settings&.distro&.cc || []

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

    # Pull the report. There are 3 scenarios here.
    # 1. :id is valid timestamp
    # 2. :id is 'latest' or 'new' (TODO: implement new)
    # 3. :id is invalid timestamp

    # NTS: This is only a case to add 'new' later.
    case # rubocop:disable Style/EmptyCaseCondition
    when (report = Report.find(timestamp: params[:id])&.first)
      # Scenario #1
      @report = report
    when params[:id] == 'latest'
      # Scenario #2
      @report = Report.latest.first
    end

    unless @report
      # Scenario #3
      status 404
      return slim :_alert, locals: { type: :error, msg: 'Email failed. Invalid report id.' }, layout: nil
    end

    subject = "[BMS] Snapshot Report - #{display_time(@report.timestamp)}"

    # Process html body
    html = Roadie::Document.new(slim(:report, layout: :layout_email))
    html.url_options = {
      host: 'bms.prod8.bip.va.gov',
      protocol: 'https'
    }
    html.asset_providers = [
      Roadie::FilesystemProvider.new(File.expand_path('public', settings.root))
    ]
    html.add_css scss(:styles)

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
      raise if settings.development?

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
    latest = Report.latest.first
    return slim 'p There are 0 reports found in the database.' if latest.nil?

    timestamp = latest.timestamp if timestamp == 'latest'
    if (@report = Report.find(timestamp: timestamp).first)
      @header = 'BMS Health Report'
      @caption = display_time(@report.timestamp)
      slim :tabbed_report
    else
      slim 'p No result found.'
    end
  end

  get '/list' do
    @reports = Report.all
    slim :reports
  end
end
