# frozen_string_literal: true

require 'json'
require 'mail'
require 'roadie'

require 'application_controller'
require 'display_helpers'
require 'email_helpers'
require 'report_helpers'

# Controller to handle health reports
class ReportsController < ApplicationController
  helpers ApplicationHelpers
  helpers EmailHelpers
  helpers ReportHelpers

  get '/' do
    begin
      @report = get_report
    rescue => e # rubocop: disable Style/RescueStandardError
      logger.error e
      return "There was an error while trying to generate report: #{e}"
    end

    heading 'BMS Health Report'
    js 'report.js'

    respond_to do |format|
      format.html { slim :tabbed_report }
      format.json do
        @report.to_json
      end
    end
  end

  post '/email' do
    # Validation
    params do
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

    @report = get_report

    unless @report
      status 404
      return slim :_alert, locals: { type: :error, msg: 'Email failed. Failed to fetch report from api server.' }, layout: nil
    end

    subject = "[BMS] Snapshot Report - #{display_time(@report[:date])}"

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
end
