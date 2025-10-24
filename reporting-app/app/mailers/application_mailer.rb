# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: ENV["AWS_SES_FROM_EMAIL"] || ENV["SES_EMAIL"]
  layout "mailer"
end
