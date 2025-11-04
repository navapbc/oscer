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
    OpenStruct.new(
      member_email: "member@example.com",
      member_name: OpenStruct.new(first: "John"),
      certification_requirements: OpenStruct.new(
        certification_date: Date.new(2024, 1, 1),
        due_date: 7.days.from_now
      )
    )
  end
end
