# frozen_string_literal: true

require 'faraday'
require 'json'
require 'uri'

require 'application_helpers'

# Helper functions for report page
module ReportHelpers
  include ApplicationHelpers

  def get_report # rubocop:disable Naming/AccessorMethodName
    # Get data from api
    report = api_fetch('/report')

    # Translate the CPU/Memory fields to percentages for report
    if report.key?(:nodes)
      report[:nodes].map do |node|
        if node.key? :cpu
          utilized = convert_mcores(node[:cpu][:utilized])
          total = convert_mcores(node[:cpu][:allocatable])
          percentage = if total.zero?
                         0
                       else
                         (utilized / total.to_f).round(2) * 100
                       end
          node.delete :cpu
          node[:cpu_percentage] = percentage
        end
        if node.key? :memory # rubocop:disable Style/Next
          utilized = convert_ram(node[:memory][:utilized])
          total = convert_ram(node[:memory][:allocatable])
          percentage = if total.zero?
                         0
                       else
                         (utilized / total.to_f).round(2) * 100
                       end
          node.delete :memory
          node[:memory_percentage] = percentage
        end
      end
    end
    report
  end
end
