# frozen_string_literal: true

require 'json'

require 'application_controller'

# Controller to handle health reports
class NamespaceController < ApplicationController
  get '/:id' do
    @namespace = Namespace[params[:id]]
    @header = "Namespace: #{@namespace&.name || 'Unknown'}"
    respond_to do |format|
      format.html { slim :namespace }
      # format.json { @payload.to_json }
    end
  end
end
