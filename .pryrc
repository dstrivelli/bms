# frozen_string_literal: true

require 'ohm'

%w[connectors models helpers controllers].each do |dir|
  $LOAD_PATH.unshift(File.expand_path(dir, __dir__))
  Dir.glob("./#{dir}/**/*.rb").sort.each { |file| require file }
end

# Filter out any stacktrace that is not within the confines of our app
Pry.config.exception_handler = proc do |output, exception, _pry_|
  output.puts exception.to_s
  filtered = exception.backtrace.select { |line| line.include? 'bms' }
  output.puts filtered.first.to_s
end

Pry::Commands.block_command 'zan', 'Echo current line', interpolate: false do
  if target.respond_to?(:source_location)
    file, line = target.source_location
    file = File.expand_path(file)
  else
    file = File.expaned_path(target.eval('__FILE__'))
    line = target.eval('__LINE__')
  end

  text = File.readlines(file)[line - 1]
  eval_string.replace(text.chomp(''))
  # run "fix-indent"
  # run "show-input"

  # binding.irb
end

# vim:ft=ruby
