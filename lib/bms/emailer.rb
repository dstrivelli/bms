require 'mail'
require 'slim'

require 'bms/result'

module BMS
  module Emailer
    def self.send(result:, template:, to: [], cc: [])
      to = [to] if to.is_a? String
      cc = [cc] if cc.is_a? String

      # Render HTML for report
      context = OpenStruct.new({ result: result })
      binding.remote_pry
      html = Slim::Template.new(template).render(context)

      mail = Mail.new do
        from 'do_not_reply@va.gov'
        to to.join(',')
        cc cc.join(',') unless cc.empty?
        subject "[BMS] Snapshot Report - #{Time.at(result[:timestamp]).strftime('%Y-%m-%d %I:%M%P')}"
        html_part do
          content_type 'text/html; charset=UTF-8'
          body html
        end
      end
      mail.delivery_method :smtp, address: 'localhost', port: 1025
      mail.deliver
    end
  end # Emailer
end # BMS
