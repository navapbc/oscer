# frozen_string_literal: true

class MemberMailer < ApplicationMailer
  layout "mailer"

  def exempt_email(certification)
    @certification = certification
    mail(
      to: certification.member_email,
      subject: "No Action Needed: You're Exempt for #{certification.certification_requirements.certification_period}"
    )
  end

  def action_required_email(certification)
    @certification = certification
    mail(
      to: certification.member_email,
      subject: "Action Needed: Please Submit Your Community Engagement Activities"
    )
  end
end
