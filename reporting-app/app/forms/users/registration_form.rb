# frozen_string_literal: true

class Users::RegistrationForm
  include ActiveModel::Model

  attr_accessor :email, :password, :password_confirmation, :spam_trap

  validates :email, :password, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }

  validates :password, confirmation: true, if: -> { password.present? }

  validates :spam_trap, absence: true
end
