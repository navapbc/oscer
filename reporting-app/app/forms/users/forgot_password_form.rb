# frozen_string_literal: true

class Users::ForgotPasswordForm
  include ActiveModel::Model

  attr_accessor :email, :spam_trap

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :spam_trap, absence: true
end
