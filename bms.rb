#!/usr/bin/env ruby

require 'kubeclient'
require 'mail'
require 'optparse'
require 'prometheus/api_client'
require 'pry'
require 'slim'
require 'yaml'

require_relative 'helpers'

# Some ActiveSupport helpers
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/hash/keys'

options = { output: :email, debug: false }
OptionParser.new do |opts|
  opts.banner = "Usage: #{0} [options]"
  opts.on('-d', '--debug', 'Turn on debug mode.') { options[:debug] = true }
  opts.on('-n', '--in FILE', 'Use yaml FILE instead of polling.') { |filename| options[:in] = filename }
  opts.on('-o', '--out [TYPE]', ['email', 'file', 'screen'], 'Where to send the report.') do |o|
    options[:output] = o.to_sym
  end
end.parse!

# Variables
results = OpenStruct.new
site_path = "http://prod8-prometheus-operator-prometheus.monitoring.svc.prod8:9090"

if options.has_key? :in
  results = YAML.load(File.read(options[:in])).deep_transform_keys(&:to_sym)
else
  # Setup connection to Kubernetes
  secrets_dir = ENV['TELEPRESENCE_ROOT'].nil? ? '' : ENV['TELEPRESENCE_ROOT']
  secrets_dir = File.join(secrets_dir, '/var/run/secrets/kubernetes.io/serviceaccount/')
  auth_options = {
    bearer_token_file: File.join(secrets_dir, 'token')
  }
  ssl_options = {}
  if File.exists? File.join(secrets_dir, 'ca.crt')
    ssl_options[:ca_file] = File.join(secrets_dir, 'ca.crt')
  end
  kube = Kubeclient::Client.new(
    'https://kubernetes.default.svc',
    'v1',
    auth_options: auth_options,
    ssl_options: ssl_options
  )
  namespace = File.read File.join(secrets_dir, 'namespace')

  # Setup connection to Prometheus
  prom = Prometheus::ApiClient.client(url: site_path)

  # Setup some helper lambdas
  q = lambda { |query| prom.query(query: query) }
  single_value = lambda { |query| q[query]['result'].first['value'].last }
  multi_value = lambda { |query, name| q[query]['result'].map { |x| { name: x['metric'][name.to_s], value: x['value'].last } } }
  fields_query = lambda { |query, fields| q[query]['result'].map { |x| x['metric'].slice(*fields.map{|y| y.to_s}) } }
  enum_query = lambda { |query, values| values.map { |v| { name: v, value: single_value[query % {value: v}]} } }

  # Get nodes
  nodes = kube.get_nodes selector: '!node-role.kubernetes.io/master'
  node_arr = nodes.map { |x| x[:metadata][:name] }

  ###
  # Kubernetes Node Information
  ###

  cpu_saturation = lambda do |n|
    rtn = single_value[%Q[sum(kube_pod_container_resource_requests_cpu_cores{node="#{n}"})/sum(kube_node_status_allocatable_cpu_cores{node="#{n}"})]]
    return rtn.to_f * 100
  end

  mem_saturation = lambda do |n|
    rtn = single_value[%Q[sum(kube_pod_container_resource_requests_memory_bytes{node="#{n}"}) / sum(kube_node_status_allocatable_memory_bytes{node="#{n}"})]]
    return rtn.to_f * 100
  end

  results[:nodes] = nodes.map do |node|
    {
      name: node[:metadata][:name],
      statuses: node[:status][:conditions].select {|c| c[:status] == 'True'}.map {|x| x[:type]},
      cpu_allocation_percent: cpu_saturation[node[:metadata][:name]],
      ram_allocation_percent: mem_saturation[node[:metadata][:name]],
    }
  end

  ###
  # Kubernetes Pod Info
  ###

  results[:unhealthy_pods] = kube.get_pods(field_selector: 'status.phase!=Running,status.phase!=Succeeded').map do |p|
    {
      name: p[:metadata][:name],
      namespace: p[:metadata][:namespace],
      status: p[:status][:phase],
    }
  end

  # Pods that have restarted in the past 24h
  qry = 'floor(delta(kube_pod_container_status_restarts_total[24h])) != 0'
  results[:pod_restarts] = multi_value[qry, :pod]

  # Nodes with high load (5m?)
  # Deployments with mismatching requested v ready
end

# Render HTML for report
context = Context.new
context[:results] = results
html = Slim::Template.new('views/report.slim', pretty: true).render(context)

case options[:output]
when :email
  mail = Mail.new do
    from 'do_not_reply@va.gov'
    to 'alexander.loy@va.gov'
    subject "[BMS] Daily Health Report - #{Time.now.strftime('%Y-%m-%d')}"
    html_part do
      content_type 'text/html; charset=UTF-8'
      body html
    end
  end
  if options[:debug]
    mail.delivery_method :smtp, address: 'localhost', port: '1025'
  else
    mail.delivery_method :smtp, address: 'smtp.va.gov', port: '25'
  end
  mail.deliver
when :file
  File.open('report.html', 'w') do |f|
    f.puts html
  end
when :screen
  puts html
end

puts results.to_h.deep_transform_keys(&:to_s).to_yaml if options[:debug]
