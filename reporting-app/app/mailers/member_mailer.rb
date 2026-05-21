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
    @hours_reported, @hours_needed = hours_reported_and_needed_for_mailer(hours_data, target_hours)
    @deadline = certification.certification_requirements.due_date.strftime("%B %d, %Y")
    @login_url = root_url

    mail(to: certification.member_email, subject: t(".subject", hours_needed: @hours_needed, deadline: @deadline))
  end

  # Generic CE shortfall: one or both of hours and income sections (flags + optional aggregates from the listener).
  def insufficient_community_engagement_email
    certification = params[:certification]
    hours_data = params[:hours_data]
    income_data = params[:income_data]
    target_hours = params[:target_hours] || HoursComplianceDeterminationService::TARGET_HOURS
    target_income = params[:target_income] || IncomeComplianceDeterminationService::TARGET_INCOME_MONTHLY

    show_hours_flag = params[:show_hours_insufficient]
    show_income_flag = params[:show_income_insufficient]
    @first_name = certification.member_name.first
    @deadline = certification.certification_requirements.due_date.strftime("%B %d, %Y")
    @login_url = root_url
    helpers = ActionController::Base.helpers

    @show_hours = false
    if show_hours_flag && hours_data.present?
      @show_hours = true
      @hours_reported, @hours_needed = hours_reported_and_needed_for_mailer(hours_data, target_hours)
    end

    @show_income = false
    if show_income_flag && income_data.present?
      @show_income = true
      reported = income_data[:total_income].to_d
      target = target_income.to_d
      @income_reported = reported.round
      @income_needed = [ target - reported, 0 ].max.round
    end

    subject =
      if @show_hours && @show_income
        t(
          ".subject_both",
          hours_needed: @hours_needed,
          income_needed: helpers.number_to_currency(@income_needed, precision: 0),
          deadline: @deadline
        )
      elsif @show_hours
        t(".subject_hours_only", hours_needed: @hours_needed, deadline: @deadline)
      elsif @show_income
        t(
          ".subject_income_only",
          income_needed: helpers.number_to_currency(@income_needed, precision: 0),
          deadline: @deadline
        )
      else
        raise ArgumentError,
          "insufficient_community_engagement_email needs at least one visible section " \
          "(set show_hours_insufficient with hours_data, or show_income_insufficient with income_data)"
      end

    mail(to: certification.member_email, subject: subject)
  end

  private

  # Matches certification_cases hours summary tables: shortfall from raw total_hours, each value rounded for display (precision 0, half up).
  def hours_reported_and_needed_for_mailer(hours_data, target_hours)
    raw_total = BigDecimal(hours_data[:total_hours].to_s)
    raw_needed = [ BigDecimal(target_hours.to_s) - raw_total, 0 ].max
    [
      raw_total.round(0, :half_up).to_i,
      raw_needed.round(0, :half_up).to_i
    ]
  end
end
