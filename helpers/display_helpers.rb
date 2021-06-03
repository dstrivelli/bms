# frozen_string_literal: true

# Helpers for displaying data
module DisplayHelpers
  require 'active_support'
  require 'active_support/core_ext/numeric/conversions'
  require 'active_support/core_ext/string/inflections'

  require 'application_helpers'

  # Setup acronyms used in reports.
  ActiveSupport::Inflector.inflections(:en) do |inflect|
    inflect.acronym 'BMS'
    inflect.acronym 'CPU'
    inflect.acronym 'URI'
    inflect.acronym 'URIs'
    inflect.acronym 'URL'
    inflect.acronym 'URLs'
    inflect.acronym 'RAM'
  end

  ##
  # Does a very simple check taking the name of a variable to use to check the
  # value against +value+

  def active?(variable, value, string = 'active')
    eval("@#{variable} == '#{value}'") ? string : '' # rubocop:disable all
  end

  def active_app?(app)
    app = [app] if app.is_a? String
    app.include?(@active_app) ? 'active' : ''
  end

  def bootstrap_class_for(type)
    case type
    when :success
      'alert-success'
    when :error
      'alert-danger'
    when :alert
      'alert-warning'
    when :notice
      'alert-info'
    else
      type.to_s
    end
  end

  def bootstrap_color_for(value)
    value = value.downcase.to_sym
    case value
    when :green, :success, :pass, :true # rubocop:disable Lint/BooleanSymbol
      'success'
    when :alert, :warning, :yellow, :warn, :unknown
      'warning'
    when :danger, :error, :red, :fail, :false # rubocop:disable Lint/BooleanSymbol
      'danger'
    else
      value.to_s
    end
  end

  def current?(path = '/')
    request.path_info == path ? 'current' : nil
  end

  def parse_percentage(value, precision: 0)
    value = value.to_f.round(precision)
    payload = { value: value }
    payload[:text] = "#{value}%"
    payload[:bg] = case value
                   when 90..100
                     'bg-danger'
                   when 75..89
                     'bg-warning'
                   else
                     'bg-success'
                   end
    payload
  end

  def light_for_node(node)
    light = :green
    text = []
    # Check status
    unless node.conditions.include? 'Ready'
      text << 'Node is not ready.'
      light = :red
    end
    %w[OutOfDisk MemoryPressure DiskPressure PIDPressure].each do |condition|
      if node.conditions.include? condition
        text << "Node is suffering #{condition}."
        light = :yellow unless light == :red
      end
    end
    # Check Utilization

    %w[cpu ram].each do |resource|
      if node.attributes["#{resource}_utilization_percent".to_sym].to_i > 95
        text << "Node has high #{resource.upcase} utilization."
        light = :yellow unless light == :red
      end
    end
    [light, text]
  end

  def light_for_app(app)
    light = :green
    namespaces = Namespace.find(app: app)
    text = ["#{app} has #{namespaces.size} namespaces."]
    namespaces.each do |namespace|
      ns_light, ns_text = light_for_namespace(namespace)
      case ns_light
      when :yellow
        light = :yellow unless light == :red
        text += ns_text.map { |elem| "#{namespace.name}/#{elem}" }
      when :red
        light = :red
        text += ns_text.map { |elem| "#{namespace.name}/#{elem}" }
      end
    end
    [light, text]
  end

  def light_for_namespace(namespace)
    light = :green
    text = []
    namespace.deployments.each do |deployment|
      deploy_light, deploy_text = light_for_deployment(deployment)
      case deploy_light
      when :yellow
        light = :yellow unless light == :red
        text += deploy_text.map { |elem| "#{deployment.name}: #{elem}" }
      when :red
        light = :red
        text += deploy_text.map { |elem| "#{deployment.name}: #{elem}" }
        break
      end
    end
    [light, text]
  end

  def light_for_deployment(deployment)
    light = :green
    text = []
    # Check readiness probe
    # Check replicas
    if deployment.replicas != deployment.ready_replicas
      light = :yellow unless light == :red
      text << "Desired replicas (#{deployment.replicas}) does not match ready replicas (#{deployment.ready_replicas})."
      if deployment.ready_replicas.zero?
        light = :red
        text << 'The ready replicas is zero.'
      end
    end
    [light, text]
  end

  def light_for(kind, obj)
    # Setup result object
    result = OpenStruct.new
    result.light = :green
    result.text = []

    case kind.downcase.to_sym
    when :daemonset
      desired = obj.status.desiredNumberScheduled
      current = obj.status.currentNumberScheduled
      if desired != current
        result.light = :red
        result.text << "The desired replicas (#{desired}) does not match current replicas (#{current})."
      end
    when :deployment
      # Check availability
      obj.status.conditions.each do |condition|
        if condition.type == 'Available' && condition.status == 'False'
          result.light = :red
          result.text << condition.message
        end
      end
    when :pod
      # Check if Successful first.
      if obj.status.phase != 'Succeeded'
        # Check conditions
        obj.status.conditions.each do |condition|
          if condition.type == 'Ready' && condition.status == 'False'
            result.light = :red
            result.text << condition.message
          end
        end
      end
    when :statefulset
      desired = obj.spec.replicas
      ready = obj.status.readyReplicas
      if desired != ready
        result.light = :red
        result.text << "The desired replicas (#{desired}) does not match the ready replicas (#{ready})."
      end
    else
      result.light = :error
      result.text << "Error: Unable to generate a light for #{obj.kind}."
    end

    # rubocop:disable Layout/CaseIndentation, Layout/EndAlignment
    result.class_img, result.class_lightbg, result.class_darkbg = case result.light
    when :green
      ['fas fa-circle green-text', 'green-text', 'green']
    when :yellow
      ['fas fa-circle yellow-text', 'yellow-text', 'yellow']
    when :red
      ['fas fa-circle red-text', 'red-text', 'red white-text']
    when :error
      ['fas fa-exclaimation-circle red-text', 'red-text', 'red white-text']
    else
      ['', '']
    end
    # rubocop:enable Layout/CaseIndentation, Layout/EndAlignment

    result
  end

  def image_for(kind, obj)
    case kind.downcase.to_sym
    when :daemonset, :deployment, :statefulset
      containers = obj.spec.template.spec.containers
    when :pod
      containers = obj.spec.containers
    end

    primary = containers.first.image
    containers.each do |container|
      primary = container.image if /^container-registry/.match? container.image
    end
    primary.split('/').last
  end

  def image_and_tag_for(kind, obj)
    image_for(kind, obj).split(':', 2)
  end

  def ready_string_for(kind, obj)
    case kind.downcase.to_sym
    when :daemonset
      desired = obj.status.desiredNumberScheduled
      ready = obj.status.currentNumberScheduled
    when :deployment
      desired = obj.spec.replicas
      ready = obj.status.readyReplicas
      ready = 0 if ready.nil?
    when :pod
      desired = obj.spec.containers.length
      ready = 0
      obj.status.containerStatuses.each do |status|
        ready += 1 if status.ready == true
      end
    when :statefulset
      desired = obj.spec.replicas
      ready = obj.status.readyReplicas
    end

    "#{ready}/#{desired}"
  end

  def display_healthy_string(healthy)
    case healthy.downcase
    when 'true'
      'Healthy'
    when 'false'
      'Unhealthy'
    when 'unknown'
      'Unknown'
    else
      'ERROR'
    end
  end

  def count_restarts(pod)
    restarts = 0

    pod.status.containerStatuses.each do |status|
      restarts += status.restartCount
    end

    restarts
  end

  def link_for(kind, *opts)
    case kind.to_s.downcase.to_sym
    when :deployment
      "/deployments/#{opts[0]}/#{opts[1]}"
    when :namespace
      "/ns/#{opts[0]}"
    when :node
      "/nodes/#{opts[0]}"
    else
      ''
    end
  end

  def join_errors(obj, sep: "\n")
    obj[:errors].join(sep)
  rescue # rubocop:disable Style/RescueStandardError
    ''
  end

  def display(value)
    display_value('', value)
  end

  def display_time(time)
    time = Time.parse(time) if time.is_a? String
    time = time.localtime if time.utc?
    time.strftime('%m/%d/%Y %l:%M%P')
  end

  def display_timestamp(timestamp)
    Time.at(timestamp).strftime('%B %e, %Y %l:%M%P')
  end

  def display_heading(name)
    heading = name.dup.to_s
    heading.slice!(/_percent$/)
    heading.titleize
  end

  def display_value(name, value)
    name = name.to_s
    method_name = "display_#{value.class.name.downcase}"
    if respond_to? method_name
      send(method_name, name, value)
    else
      send(:display_string, name, value)
    end
  end

  def display_array(name, value, delimiter = ', ')
    display_string(name, value.join(delimiter))
  end

  def display_string(_name, value)
    # Filter IP addresses because the VA thinks they
    # are a matter of national security.
    value.to_s.gsub(/ip-[0-9]{1,3}-[0-9]{1,3}/, 'ip-x-x')
  end

  def display_number(name, value)
    if name.end_with?('_percent')
      value.to_s(:percentage, precision: 0)
    else
      value
    end
  end
  alias display_integer display_number
  alias display_float   display_number
end
