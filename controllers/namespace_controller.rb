# frozen_string_literal: true

require 'json'

require 'application_controller'

# Controller to handle health reports
class NamespaceController < ApplicationController
  get '/:id' do
    param :id, String, required: true

    @namespace = if params[:id] =~ /\A[0-9]*\Z/
                   Namespace[params[:id]]
                 else
                   Namespace.with(:name, params[:id])
                 end
    return slim('p No namespace with that id/name.') if @namespace.nil?

    @events = @namespace.events.sort_by(:lastTimestamp, order: 'DESC')

    heading "Namespace: #{@namespace&.name || 'Unknown'}"

    respond_to do |format|
      format.html { slim :namespace }
      # format.json { @payload.to_json }
    end
  end
end
