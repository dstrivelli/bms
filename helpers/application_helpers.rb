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
    return 0 if mcores.nil?

    unit = mcores[-1].to_sym
    count = mcores[0..-2].to_f
    result = if CPU_ORDERS_OF_MAGNITUDE[unit]
               count / CPU_ORDERS_OF_MAGNITUDE[unit]
             else
               count
             end
    result.round(precision)
  end

  def convert_to_mcores(float)
    return '0m' if float.zero?

    "#{(float * CPU_ORDERS_OF_MAGNITUDE[:m]).floor}m"
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

  def convert_to_ram(int)
    return '0Ki' if int.zero?

    oom = {
      Ei: 1024**6,
      Pi: 1024**5,
      Ti: 1024**4,
      Gi: 1024**3,
      Mi: 1024**2,
      Ki: 1024
    }

    oom.each_key do |key|
      # if larger than this key, convert and add key
      return "#{(int / oom[key]).round(2)}#{key}" if int > oom[key]
    end
  end

  def sum_resources(pod)
    rtn = {
      cpu_requested: 0.0,
      cpu_limits: 0.0,
      ram_requested: 0.0,
      ram_limits: 0.0
    }
    pod.spec.containers.each do |container|
      rtn[:cpu_requested] += convert_mcores(container&.resources&.requests&.cpu)
      rtn[:cpu_limits] += convert_mcores(container&.resources&.limits&.cpu)
      rtn[:ram_requested] += convert_ram(container&.resources&.requests&.memory)
      rtn[:ram_limits] += convert_ram(container&.resources&.limits&.memory)
    end
    rtn.merge({
                cpu_requested_str: convert_to_mcores(rtn[:cpu_requested]),
                cpu_limits_str: convert_to_mcores(rtn[:cpu_limits]),
                ram_requested_str: convert_to_ram(rtn[:ram_requested]),
                ram_limits_str: convert_to_ram(rtn[:ram_limits])
              })
  end

  # Add two resource bundles together.
  def add_resources(seta, setb)
    seta ||= { cpu_requested: 0.0, cpu_limits: 0.0, ram_requested: 0.0, ram_limits: 0.0 }
    %i[cpu_requested cpu_limits ram_requested ram_limits].each do |key|
      seta[key] += (setb[key] || 0.0)
    end
    seta.merge({
                 cpu_requested_str: convert_to_mcores(seta[:cpu_requested]),
                 cpu_limits_str: convert_to_mcores(seta[:cpu_limits]),
                 ram_requested_str: convert_to_ram(seta[:ram_requested]),
                 ram_limits_str: convert_to_ram(seta[:ram_limits])
               })
  end

  def sort_events(events)
    return events if events.empty?

    events.to_a.sort_by(&:lastTimestamp)
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
