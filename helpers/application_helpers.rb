# frozen_string_literal: true

require 'socket'
require 'timeout'

# Module to house helpers to the general application
module ApplicationHelpers
  # CONSTANTS
  CPU_ORDERS_OF_MAGNITUDE = {
    m: 1000,
    n: 1000**3
  }.freeze

  RAM_ORDERS_OF_MAGNITUDE = {
    Ki: 1024,
    Mi: 1024**2,
    Gi: 1024**3,
    Ti: 1024**4,
    Pi: 1024**5,
    Ei: 1024**6,
    K: 1000,
    M: 1000**2,
    G: 1000**3,
    T: 1000**4,
    P: 1000**5,
    E: 1000**6
  }.freeze

  def convert_mcores(mcores, precision: 2)
    return 0.0 if mcores.nil?

    unit = mcores[-1].to_sym
    count = mcores[0..-2].to_f
    result = if CPU_ORDERS_OF_MAGNITUDE[unit]
               count / CPU_ORDERS_OF_MAGNITUDE[unit]
             else
               count
             end
    result.round(precision)
  end

  def convert_ram(ram)
    return 0 if ram.nil?

    ram_regex = /(?<count>[0-9]*)(?<unit>(#{RAM_ORDERS_OF_MAGNITUDE.keys.join('|')}))?$/
    matches = ram_regex.match(ram)
    raise "Error in #convert_ram. The value #{ram} does not match the regex." if matches.nil?

    if matches[:unit].nil?
      matches[:count].to_i
    else
      matches[:count].to_i * RAM_ORDERS_OF_MAGNITUDE[matches[:unit].to_sym]
    end
  end

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
