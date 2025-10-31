# frozen_string_literal: true

class MemberMailerPreview < Lookbook::Preview
  layout "mailer"

  def action_required_email
    certification = FactoryBot.create(:certification)
    render template: "member_mailer/action_required_email", locals: { certification: certification }
  end

  def exempt_email
    certification = FactoryBot.create(:certification)
    render template: "member_mailer/exempt_email", locals: { certification: certification }
  end
end
