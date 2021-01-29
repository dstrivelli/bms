# frozen_string_literal: true

require 'socket'
require 'timeout'

# Module to house helpers to the general application
module ApplicationHelpers
  def full_title
    title = (settings.respond_to(:title) ? settings.title : 'BMS')
    if @title
      title += " - #{@title}"
    elsif @heading
      title += " - #{@heading}"
    end
    title
  end

  def title(value)
    @title = value
  end

  def path_to(script)
    case script
    when :jquery then 'https://ajax.googleapis.com/libs/jquery/3.4.1/jquery.min.js'
    else "/js/#{script}"
    end
  end

  def javascripts
    js = []
    js << settings.javascripts if settings.respond_to?('javascripts')
    js << @js if @js
    js.flatten.uniq.map do |script|
      path_to script
    end
  end

  def js(*args)
    @js ||= []
    @js << args
    @js.flatten.uniq
  end

  def js_clear
    @js = []
  end

  def heading(value = nil)
    @heading = value if value
    if @heading
      @heading
    elsif settings.respond_to?(:heading)
      settings.heading
    else
      'BMS'
    end
  end

  def caption(value = nil)
    @caption = value if value
    if @caption
      @caption
    elsif settings.respond_to?(:caption)
      settings.caption
    else
      ''
    end
  end

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
