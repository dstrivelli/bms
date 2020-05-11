# frozen_string_literal: true

# Turn off actually sending emails
Mail.defaults do
  delivery_method :test
end
