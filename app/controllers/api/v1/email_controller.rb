module Api
  module V1
    class EmailController < ApplicationController
      def inquiry
        UserMailer.welcome_email.deliver_now
        render json: { status: "ok" }
      end
    end
  end
end
