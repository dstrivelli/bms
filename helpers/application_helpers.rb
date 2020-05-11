# frozen_string_literal: true

require 'socket'
require 'timeout'

# Module to house helpers to the general application
module ApplicationHelpers
  def port_open?(ip, port, seconds = 1)
    Timeout.timeout(seconds) do
      TCPSocket.new(ip, port).close
    end
    true
  rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    false
  rescue Timeout::Error
    false
  end

  def worker_pid
    # Validate pid file exists
    pid_file = Settings&.worker&.pid_file || '/tmp/bmw_worker.pid'
    pid = File.read(pid_file).to_i
    return nil if pid.zero?

    # Validate process is still running
    Process.getpgid(pid)
    pid
  rescue Errno::ENOENT, Errno::ESRCH
    nil
  end

  def worker_running?
    worker_pid ? true : false
  end
end
