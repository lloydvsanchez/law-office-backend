module Api
  module V1
    class EmailController < ApplicationController
      def inquiry
        UserMailer.with(inquiry: params_inquiry).inquiry_email.deliver_now

        render json: { status: "ok", properties: params.permit!.inspect }
      end

      private

      def params_inquiry
        params.permit(%i[name contact preferred_contact concern dates location message])
      end
    end
  end
end
