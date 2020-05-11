#!/usr/bin/env ruby
# frozen_string_literal: true

ACTIONS = %w[install uninstall upgrade].freeze

if ARGV.empty? || !ACTIONS.include?(ARGV[0])
  puts "You must call this script with one of the following options: #{ACTIONS.join(', ')}"
  exit 1
end

action = ARGV.shift

cmd = ['helm3']
case action
when 'install', 'upgrade'
  cmd.push action, 'redis', 'bitnami/redis', '--set cluster.enabled=false', '--set clusterDomain=prod8'
when 'uninstall'
  cmd.push 'uninstall', 'redis'
end

cmd.push(*ARGV) unless ARGV.empty?

puts "Running: #{cmd.join(' ')}"
puts '-------------------------'
exec(*cmd)
