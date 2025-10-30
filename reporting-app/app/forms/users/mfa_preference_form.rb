# frozen_string_literal: true

class Users::MfaPreferenceForm
  include ActiveModel::Model

  attr_accessor :mfa_preference

  validates :mfa_preference, presence: true
  validates :mfa_preference, inclusion: { in: User.mfa_preferences.keys }, if: -> { mfa_preference.present? }
end
