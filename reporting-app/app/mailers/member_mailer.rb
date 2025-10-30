# frozen_string_literal: true

class MemberMailer < ApplicationMailer
  layout "mailer"

  def exempt_email
    certification = params[:certification]
    @first_name = certification.member_name.first
    reasons = params[:reasons] || []
    @exemption_reasons = reasons.map { |r| r.to_s.humanize }.join(", ")
    @period = certification.certification_requirements.certification_date.strftime("%B %Y")

    mail(
      to: certification.member_email,
      subject: t(".subject", period: @period)
    )
  end

  def action_required_email
    certification = params[:certification]
    @first_name = certification.member_name.first
    @due_date = certification.certification_requirements.due_date.strftime("%B %d, %Y")
    @login_url = root_url

    mail(
      to: certification.member_email,
      subject: t(".subject")
    )
  end
end
