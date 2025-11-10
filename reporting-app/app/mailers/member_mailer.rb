# frozen_string_literal: true

class MemberMailer < ApplicationMailer
  layout "mailer"

  def exempt_email
    certification = params[:certification]
    @first_name = certification.member_name.first
    @period = certification.certification_requirements.certification_date.strftime("%B %Y")
    @renewal_date = (certification.certification_requirements.certification_date + 30.days).strftime("%B %d, %Y")

    mail(
      to: certification.member_email,
      subject: t(".subject", period: @period),
      from: t(".shared.from_display_name") + " <#{ENV["AWS_SES_FROM_EMAIL"] || ENV["SES_EMAIL"]}>"
    )
  end

  def action_required_email
    certification = params[:certification]
    @first_name = certification.member_name.first
    @due_date = certification.certification_requirements.due_date.strftime("%B %d, %Y")
    @login_url = root_url

    mail(
      to: certification.member_email,
      subject: t(".subject"),
      from: t(".shared.from_display_name") + " <#{ENV["AWS_SES_FROM_EMAIL"] || ENV["SES_EMAIL"]}>"
    )
  end
end
