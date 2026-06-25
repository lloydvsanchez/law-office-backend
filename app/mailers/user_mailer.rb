class UserMailer < ApplicationMailer
  default from: "LawOffice Inquiry Page <onboarding@resend.dev>" # this domain must be verified with Resend

  def inquiry_email
    @inquiry = params[:inquiry]

    mail(to: [ "lloydvsanchez@gmail.com" ], subject: "Inquiry from Law Office Website")
  end
end
