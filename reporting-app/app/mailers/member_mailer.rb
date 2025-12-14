# frozen_string_literal: true

class MemberMailer < ApplicationMailer
  layout "mailer"
  default from: -> { "#{I18n.t('member_mailer.shared.from_display_name')} <#{ENV['AWS_SES_FROM_EMAIL'] || ENV['SES_EMAIL']}>" }

  def exempt_email
    certification = params[:certification]
    @first_name = certification.member_name.first
    @period = certification.certification_requirements.certification_date.strftime("%B %Y")
    @renewal_date = (certification.certification_requirements.certification_date + 30.days).strftime("%B %d, %Y")

    mail(to: certification.member_email, subject: t(".subject", period: @period))
  end

  def action_required_email
    certification = params[:certification]
    @first_name = certification.member_name.first
    @due_date = certification.certification_requirements.due_date.strftime("%B %d, %Y")
    @login_url = root_url

    mail(to: certification.member_email, subject: t(".subject"))
  end

  def compliant_email
    certification = params[:certification]
    @first_name = certification.member_name.first
    @period = certification.certification_requirements.certification_date.strftime("%B %Y")
    @renewal_date = (certification.certification_requirements.certification_date + 30.days).strftime("%B %d, %Y")

    mail(to: certification.member_email, subject: t(".subject", period: @period))
  end

  def insufficient_hours_email
    certification = params[:certification]
    hours_data = params[:hours_data]
    target_hours = params[:target_hours] || HoursComplianceDeterminationService::TARGET_HOURS

    @first_name = certification.member_name.first
    @hours_reported = hours_data[:total_hours].to_i
    @hours_needed = [ target_hours - @hours_reported, 0 ].max
    @deadline = certification.certification_requirements.due_date.strftime("%B %d, %Y")
    @login_url = root_url

    mail(to: certification.member_email, subject: t(".subject", hours_needed: @hours_needed, deadline: @deadline))
  end
end
