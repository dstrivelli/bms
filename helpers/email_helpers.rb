# frozen_string_literal: true

# Helpers for using emails
module EmailHelpers
  def validate_emails(emails, whitelists: [])
    emails = [emails] if emails.is_a? String
    result = { approved: true, reason: '', unapproved: [] }

    emails.each do |addr|
      denied = true
      whitelists.each do |test_string|
        denied = false if Regexp.new(test_string).match?(addr)
      end
      if denied
        result[:approved] = false
        result[:unapproved].append(addr)
      end
    end

    result[:reason] = "The following email addresses are not whitelisted: #{result[:unapproved].join(', ')}" unless result[:approved]
    result
  rescue RegexpError
    {
      approved: false,
      reason: 'Invalid whitelist regex in config file.',
      unapproved: []
    }
  end
end
