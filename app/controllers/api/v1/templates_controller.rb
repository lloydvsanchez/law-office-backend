module Api
  module V1
    class TemplatesController < ApplicationController
      def show
        id = params.permit(:id)[:id]
        template = DocumentTemplate.select(%i[id title description practice_area content_raw metadata]).find(id)

        render json: template&.as_json, status: :ok
      rescue => e
        Rails.logger.error "[GenerationsController] Unexpected error: #{e.message}"
        render json: "An unexpected error occurred: #{e.message}", status: :internal_server_error
      end
    end
  end
end