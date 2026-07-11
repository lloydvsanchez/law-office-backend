module Api
  module V1
    module Templates
      class RegenerationsController < ApplicationController
        # before_action :authenticate_user! # uncomment when auth is implemented

        def create
          generation_id = DocumentTemplateRegenerationService.call(
            document_template_id: regeneration_params[:id],
            description:          regeneration_params[:description]
          )

          render json: success_response(generation_id), status: :ok

        rescue DocumentTemplateRegenerationService::RegenerationError => e
          render json: error_response(e.message), status: :unprocessable_entity

        rescue ProviderUnavailableError => e
          Rails.logger.error "[RegenerationsController] Provider unavailable: #{e.message}"
          render json: error_response("Generation service is temporarily unavailable. Please try again later."), status: :service_unavailable

        rescue ActionController::ParameterMissing => e
          render json: error_response(e.message), status: :unprocessable_entity

        rescue => e
          Rails.logger.error "[RegenerationsController] Unexpected error: #{e.message}"
          render json: error_response("An unexpected error occurred"), status: :internal_server_error
        end

        private

        def regeneration_params
          params.require(:regeneration).permit(:id, :description)
        end

        def success_response(generation_id)
          {
            data: {
              generation_id:        generation_id,
              generated:            true,
              service_unavailable:  false
            },
            meta: {
              poll_url: "/api/v1/generations/#{generation_id}/status"
            },
            errors: []
          }
        end

        def error_response(message)
          {
            data:   nil,
            meta:   nil,
            errors: [message]
          }
        end
      end
    end
  end
end