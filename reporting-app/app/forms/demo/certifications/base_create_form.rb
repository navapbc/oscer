# frozen_string_literal: true

module Demo
  module Certifications
    class BaseCreateForm
      include ActiveModel::Model
      include ActiveModel::Attributes
      include Strata::Attributes

      LOOKBACK_PERIOD_OPTIONS = (1..6).to_a
      NUMBER_OF_MONTHS_TO_CERTIFY_OPTIONS = (1..6).to_a
      DUE_PERIOD_OPTIONS = [ 15, 30, 60 ] # in days
      # Minimum US Census Bureau race/ethnicity options
      RACE_ETHNICITY_OPTIONS = [
        "white",
        "black_or_african_american",
        "american_indian_or_alaska_native",
        "asian",
        "native_hawaiian_or_other_pacific_islander"
      ].freeze

      attribute :member_email, :string
      strata_attribute :member_name, :name
      strata_attribute :date_of_birth, :us_date
      attribute :case_number, :string
      attribute :icn, :string
      attribute :pregnancy_status, :boolean, default: false
      attribute :race_ethnicity, :enum, options: RACE_ETHNICITY_OPTIONS

      # TODO: add validation you can't set both certification_type and the other params?
      attribute :certification_type, :enum, options: ::Certifications::Requirements::CERTIFICATION_TYPE_OPTIONS

      strata_attribute :certification_date, :us_date

      # TODO: would maybe prefer to use ISO8601 duration values here instead of integers of months
      attribute :lookback_period, :integer, default: LOOKBACK_PERIOD_OPTIONS[0]
      attribute :number_of_months_to_certify, :integer, default: NUMBER_OF_MONTHS_TO_CERTIFY_OPTIONS[0]
      # TODO: would maybe prefer to use ISO8601 duration values here instead of integers of days
      attribute :due_period_days, :integer, default: DUE_PERIOD_OPTIONS[1]

      attribute :region, :string

      validates :certification_date, presence: true
      validates :region, inclusion: { in: proc { User.regions }, message: "is not a valid option" }, allow_blank: true

      # Name validations
      validates :member_name_first, presence: true
      validates :member_name_last, presence: true
      validates :member_name_first, :member_name_last, :member_name_middle, :member_name_suffix,
                format: { with: /\A[a-zA-Z\s\-'.]*\z/, message: "can only contain letters, spaces, hyphens, apostrophes, and periods" },
                allow_blank: true

      # TODO: may eventually want a more custom validation with clearer error
      # message about relationship to number_of_months_to_certify
      validates :lookback_period, numericality: { greater_than_or_equal_to: Proc.new { |record| record.number_of_months_to_certify } }

      validate :date_of_birth_must_be_in_past

      def locked_type_params?
        certification_type.present?
      end

      private

      def date_of_birth_must_be_in_past
        return unless date_of_birth.present?

        if date_of_birth > Date.current
          errors.add(:date_of_birth, "must be in the past")
        end
      end
    end
  end
end
