# frozen_string_literal: true

require 'json'

require 'application_controller'

# Controller to handle displaying apps
class DeploymentsController < ApplicationController
  get '/:uid' do
    @deployment = Deployment.with(:uid, params[:uid])

    heading "Deployment: #{@deployment.name}"

    # Display
    respond_to do |format|
      format.html { slim :deployment }
      # format.json { @payload.to_json }
    end
  end
end
