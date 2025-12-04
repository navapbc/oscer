# frozen_string_literal: true

class User < ApplicationRecord
  attribute :program, default: "Medicaid"
  attribute :region
  attribute :role

  devise :auth_service_authenticatable, :timeoutable
  attr_accessor :access_token

  enum :mfa_preference, { opt_out: 0, software_token: 1 }, validate: { allow_nil: true }

  has_many :tasks

  validates :provider, presence: true
  validates :role, inclusion: { in: [ "caseworker", "supervisor" ] }, allow_nil: true # Should be configurable in the future
  validates :region, inclusion: { in: [ "Northwest", "Northeast", "Southwest", "Southeast", "All" ] }, allow_nil: true # Should be configurable in the future

  def access_token_expires_within_minutes?(access_token, minutes)
    return true unless access_token.present?

    decoded_token = JWT.decode(access_token, nil, false)
    expiration_time = Time.at(decoded_token.first["exp"])

    expiration_time < Time.now + minutes.minutes
  end
end
