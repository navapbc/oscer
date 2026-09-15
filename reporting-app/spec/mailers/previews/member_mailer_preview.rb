# frozen_string_literal: true

require "ostruct"

class MemberMailerPreview < ActionMailer::Preview
  def action_required_email
    certification = mock_certification
    MemberMailer.with(certification: certification).action_required_email
  end

  def exempt_email
    certification = mock_certification
    MemberMailer.with(certification: certification).exempt_email
  end

  private

  def mock_certification
    application_date = Date.new(2025, 11, 4)
    due_date = application_date + 7.days

    OpenStruct.new(
      member_email: "member@example.com",
      member_name: OpenStruct.new(first: "John"),
      application_date:,
      evaluated_month: application_date.beginning_of_month,
      certification_requirements: OpenStruct.new(
        due_date:
      )
    )
  end
end
