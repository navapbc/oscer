# frozen_string_literal: true

class Users::UpdateEmailForm
  include ActiveModel::Model

  attr_accessor :email

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
end
