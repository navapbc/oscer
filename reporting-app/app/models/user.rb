# frozen_string_literal: true

class User < ApplicationRecord
  devise :auth_service_authenticatable, :timeoutable
  attr_accessor :access_token

  # == Enums ========================================================
  # See `technical-foundation.md#enums` for important note about enums.
  enum :mfa_preference, { opt_out: 0, software_token: 1 }, validate: { allow_nil: true }

  # == Relationships ========================================================
  has_many :tasks

  # == Validations ==========================================================
  validates :provider, presence: true

  # == Methods ==============================================================

  # Check if the access token is expired or will expire within the next `minutes` minutes.
  # Access token is only stored in the session, so it needs passed in, rather than accessed from the model.
  def access_token_expires_within_minutes?(access_token, minutes)
    return true unless access_token.present?

    decoded_token = JWT.decode(access_token, nil, false)
    expiration_time = Time.at(decoded_token.first["exp"])

    expiration_time < Time.now + minutes.minutes
  end
end
