# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  # Make sure templates in app/views/overrides are used if present
  prepend_view_path ActionView::FileSystemResolver.new(Rails.root.join("app/views/overrides"))

  default from: ENV["AWS_SES_FROM_EMAIL"] || ENV["SES_EMAIL"]
  layout "mailer"
end
