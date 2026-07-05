module Api
  module V1
    class GenerationsController < ApplicationController
      # before_action :authenticate_user! # uncomment when auth is implemented

      POLL_INTERVAL_SECONDS = ENV.fetch("GENERATION_POLL_INTERVAL_SECONDS", 5).to_i

      def status
        log = GenerationLog.includes(:template).find(params[:id])

        render json: status_response(log), status: :ok

      rescue ActiveRecord::RecordNotFound
        render json: error_response("Generation not found"), status: :not_found

      rescue => e
        Rails.logger.error "[GenerationsController] Unexpected error: #{e.message}"
        render json: error_response("An unexpected error occurred"), status: :internal_server_error
      end

      private

      def status_response(log)
        base = {
          data: {
            generation_id:        log.id,
            status:               log.status,
            trigger_type:         log.trigger_type,
            poll_interval_seconds: POLL_INTERVAL_SECONDS,
            template:             template_payload(log)
          },
          meta: {
            created_at:   log.created_at,
            completed_at: completed_at(log)
          },
          errors: log.status == "failed" ? [log.error_message] : []
        }

        base
      end

      # Only include template payload when generation is completed
      def template_payload(log)
        return nil unless log.status == "success" && log.template.present?

        template = log.template
        {
          id:            template.id,
          title:         template.title,
          description:   template.description,
          practice_area: template.practice_area,
          content_raw:   template.content_raw,
          status:        template.status,
          source:        template.source,
          created_at:    template.created_at
        }
      end

      def completed_at(log)
        # GenerationLog does not have a completed_at column —
        # use updated_at when status is terminal
        return nil unless %w[completed failed].include?(log.status)
        log.updated_at
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