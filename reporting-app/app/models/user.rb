# frozen_string_literal: true

class User < ApplicationRecord
  attribute :full_name, :string
  attribute :region, :string
  attribute :role, :string

  devise :auth_service_authenticatable, :timeoutable
  attr_accessor :access_token

  enum :mfa_preference, { opt_out: 0, software_token: 1 }, validate: { allow_nil: true }

  has_many :tasks

  validates :provider, presence: true

  scope :staff_members, -> { where.not(role: nil) }

  def self.regions
    where.not(region: nil).distinct.pluck(:region)
  end

  def access_token_expires_within_minutes?(access_token, minutes)
    return true unless access_token.present?

    decoded_token = JWT.decode(access_token, nil, false)
    expiration_time = Time.at(decoded_token.first["exp"])

    expiration_time < Time.now + minutes.minutes
  end

  def admin?
    role == "admin"
  end

  def caseworker?
    role == "caseworker"
  end

  def staff?
    admin? || caseworker?
  end
end
