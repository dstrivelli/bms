# frozen_string_literal: true

# Turn off logging
Logging.logger.root.level = Settings&.log_level || :warn
