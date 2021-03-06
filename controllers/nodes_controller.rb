# frozen_string_literal: true

require 'json'

require 'application_controller'

# Controller to handle displaying nodes
class NodesController < ApplicationController
  get '/:name' do
    param :name, String, required: true

    name = params[:name].gsub(/ip-x-x/, 'ip-10-247')
    @crumbs = {
      'Nodes' => ''
    }

    begin
      @node = settings.k8core.get_node(name)
      @metrics = settings.k8metrics.get_entity('nodes', name)
    rescue Kubeclient::ResourceNotFoundError
      @node = nil
    end

    if @node.nil?
      'No node found'
    else
      @crumbs[@node.metadata.name] = ''
      @pods = settings.k8core.get_pods(field_selector: "spec.nodeName=#{@node.metadata.name}", sort_by: '.metadata.name')

      # TODO: Move this out to a helper method
      # Calculate stats
      @stats = {
        Conditions: @node.status.conditions.select { |c| c.status == 'True' }.map!(&:type),
        CPU_percent: convert_mcores(@node.status.allocatable.cpu) / convert_mcores(@metrics.usage.cpu),
        RAM_percent: convert_mcores(@node.status.allocatable.memory) / convert_mcores(@metrics.usage.memory)
      }

      if @node.nil?
        slim :entitynotfound, locals: { kind: 'Node' }
      else
        slim :node
      end
    end
  end
end
