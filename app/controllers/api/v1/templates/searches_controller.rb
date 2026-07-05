module Api
  module V1
    module Templates
      class SearchesController < ApplicationController
        # before_action :authenticate_user! # uncomment when auth is implemented

        MAX_LIMIT = 10

        def create
          result = TemplateSearchService.call(
            query:         search_params[:query],
            user:          current_user,
            organization:  current_organization,
            limit:         resolved_limit,
            practice_area: search_params[:practice_area],
            court_level:   search_params[:court_level]
          )

          render json: success_response(result), status: :ok

        rescue ProviderUnavailableError => e
          Rails.logger.error "[SearchesController] Provider unavailable: #{e.message}"
          render json: unavailable_response, status: :ok

        rescue ActionController::ParameterMissing => e
          render json: error_response(e.message), status: :unprocessable_entity

        rescue => e
          Rails.logger.error "[SearchesController] Unexpected error: #{e.message}"
          render json: error_response("An unexpected error occurred"), status: :internal_server_error
        end

        private

        def search_params
          params.require(:search).permit(
            :query,
            :limit,
            :practice_area,
            :court_level
          )
        end

        def resolved_limit
          limit = search_params[:limit].to_i
          return TemplateSearchService::DEFAULT_LIMIT if limit <= 0
          [limit, MAX_LIMIT].min
        end

        # current_user and current_organization return nil until auth is implemented.
        # Replace these with real auth methods when authentication is added.
        def current_user
          nil
        end

        def current_organization
          nil
        end

        def success_response(result)
          {
            data: {
              results:           result[:results],
              generated:         result[:generated],
              generation_id:     result[:generation_id],
              service_unavailable: false
            },
            meta: {
              count:  result[:results].size,
              limit:  resolved_limit
            },
            errors: []
          }
        end

        def unavailable_response
          {
            data: {
              results:             [],
              generated:           false,
              service_unavailable: true
            },
            meta: {
              count: 0,
              limit: resolved_limit
            },
            errors: ["Search service is temporarily unavailable. Please try again later."]
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