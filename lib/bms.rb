require 'config'

require 'bms/result'

ENV['BMS_ROOT'] = File.expand_path('..', __dir__)

unless defined?(Settings)
  # Load settings
  Config.setup do |config|
    config.use_env = true
    config.env_prefix = 'BMS'
    config.env_separator = '__'
  end
  env = ENV.fetch('APP_ENV', 'development')
  Config.load_and_set_settings(Config.setting_files(File.join(ENV['BMS_ROOT'], 'config'), env))
end
