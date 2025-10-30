# frozen_string_literal: true

class Users::NewSessionForm
  include ActiveModel::Model

  attr_accessor :email, :password, :spam_trap

  validates :email, :password, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { email.present? }

  validates :spam_trap, absence: true
end
