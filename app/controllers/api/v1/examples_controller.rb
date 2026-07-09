module Api
  module V1
    class ExamplesController < ApplicationController
      # before_action :authenticate_user! # uncomment when auth is implemented

      DEFAULT_SIZE = 5
      MAX_SIZE     = 10

      def index
        size      = resolved_size
        templates = DocumentTemplate
          .where(status: %w[review published])
          .select(:id, :title, :description)
          .order(Arel.sql("RANDOM()"))
          .limit(size)

        render json: {
          data:   templates.map { |t| { title: t.title, description: t.description } },
          meta:   { size: templates.size },
          errors: []
        }, status: :ok

      rescue => e
        Rails.logger.error "[ExamplesController] Unexpected error: #{e.message}"
        render json: {
          data:   [],
          meta:   { size: 0 },
          errors: ["An unexpected error occurred"]
        }, status: :internal_server_error
      end

      private

      def resolved_size
        size = params[:size].to_i
        return DEFAULT_SIZE if size <= 0
        [size, MAX_SIZE].min
      end
    end
  end
end