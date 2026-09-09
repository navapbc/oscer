# frozen_string_literal: true

class Certifications::MemberData < ValueObject
  include ActiveModel::AsJsonAttributeType
  include Strata::Attributes

  class ContactData < ValueObject
    include ActiveModel::AsJsonAttributeType

    attribute :email, :string
    attribute :phone, :string # TODO: E.164 format, eventually would probably be more than one field, cell_phone, home_phone, etc
  end

  class Paycheck < ValueObject
    include ActiveModel::AsJsonAttributeType

    attribute :period_start, :date # TODO: use Strata::DateRange?
    attribute :period_end, :date
    attribute :gross, :decimal # TODO: more like Strata::Money right?
    attribute :net, :decimal # TODO: more like Strata::Money right?
    attribute :hours_worked, :decimal

    validates :period_start, presence: true
    validates :period_end, presence: true
  end

  # One activity may report hours, gross income, or both — a state reports hours and earnings for
  # the same job over the same period, and both land on one ExternalActivity row per month. There
  # is no +type+ discriminator: which values are present decides what is stored.
  class Activity < ValueObject
    include ActiveModel::AsJsonAttributeType

    CATEGORY_EDUCATION = "education"
    VERIFIED = "verified"
    VERIFICATION_STATUSES = [ VERIFIED, "self_attested", "pending" ].freeze

    # Deliberately narrower than +ExternalActivity::ALLOWED_SOURCE_TYPES+: the model's union
    # includes +batch_upload+, which must not become an accepted value for an API submission.
    ALLOWED_SOURCES = [ ExternalActivity::SOURCE_TYPES[:api] ].freeze

    ENROLLMENT_FULL_TIME = "full_time"
    ENROLLMENT_HALF_TIME = "half_time"
    # Ordered best first: HoursComplianceDeterminationService ranks reported enrollments by this order.
    ENROLLMENT_STATUSES = [ ENROLLMENT_FULL_TIME, ENROLLMENT_HALF_TIME, "less_than_half_time" ].freeze
    QUALIFYING_ENROLLMENT_STATUSES = [ ENROLLMENT_FULL_TIME, ENROLLMENT_HALF_TIME ].freeze

    # One credit hour is 12.99 clock hours per month (3 hours per week over a 4.33 week month)
    # per the Federal Register.
    CREDIT_HOURS_MULTIPLIER = BigDecimal("12.99")

    attribute :category, :string
    attribute :hours, :decimal
    attribute :credit_hours, :decimal
    attribute :gross_income, :decimal
    attribute :period_start, :date
    attribute :period_end, :date
    attribute :source, :string
    attribute :reported_at, :datetime
    attribute :employer, :string
    attribute :name, :string
    attribute :verification_status, :string
    attribute :enrollment_status, :string

    validates :category, presence: true, inclusion: { in: ::Activity::ALLOWED_CATEGORIES }
    validate :reports_hours_or_income
    validates :credit_hours, numericality: { greater_than: 0 }, allow_nil: true
    validates :credit_hours, absence: true, unless: -> { category == CATEGORY_EDUCATION }
    validates :gross_income, numericality: { greater_than: 0 }, allow_nil: true
    validates :source, presence: true, if: -> { gross_income.present? }
    validates :source, inclusion: { in: ALLOWED_SOURCES }, allow_nil: true
    validates :period_start, presence: true
    validates :period_end, presence: true
    validates :verification_status, presence: true, inclusion: { in: VERIFICATION_STATUSES }
    validates :enrollment_status, inclusion: { in: ENROLLMENT_STATUSES }, allow_nil: true
    validates :enrollment_status, absence: true, unless: -> { category == CATEGORY_EDUCATION }

    # Only verified activities count toward a certification.
    def verified?
      verification_status == VERIFIED
    end

    # Education activities may report credit hours in place of clock hours.
    def education_credit_hours?
      category == CATEGORY_EDUCATION && credit_hours.present?
    end

    # Enrollment stands in for hours the same way credit hours do.
    def education_enrollment?
      category == CATEGORY_EDUCATION && enrollment_status.present?
    end

    def qualifying_enrollment?
      QUALIFYING_ENROLLMENT_STATUSES.include?(enrollment_status)
    end

    # Reported hours, or their credit-hour equivalent when hours were omitted.
    def clock_hours
      return hours if hours.present?

      credit_hours * CREDIT_HOURS_MULTIPLIER if education_credit_hours?
    end

    private

    # Replaces the old "hourly activities must report hours" rule. An enrollment-only education
    # activity counts as reporting something: it stores no row, but satisfies the hours
    # requirement through HoursComplianceDeterminationService#education_enrollment_compliant?.
    def reports_hours_or_income
      return if hours.present? || credit_hours.present? ||
                enrollment_status.present? || gross_income.present?

      errors.add(:base, :hours_or_gross_income_required)
    end
  end

  class PayrollAccount < ValueObject
    include ActiveModel::AsJsonAttributeType

    attribute :company_name, :string
    attribute :paychecks, :array, of: Paycheck.to_type
  end

  class Period < ValueObject
    include ActiveModel::AsJsonAttributeType
    attribute :period_start, :date
    attribute :period_end, :date
  end
  class Exemption < ValueObject
    include ActiveModel::AsJsonAttributeType

    attribute :type, :string
    attribute :value, :boolean
    attribute :periods, :array, of: Period.to_type
    attribute :verification_status, :string
  end

  attribute :account_email, :string
  attribute :va_icn, :string
  strata_attribute :ssn, :tax_id
  attribute :contact, ContactData.to_type
  attribute :name, ActiveModel::Type::Json.new(Strata::Name)
  attribute :address, ActiveModel::Type::Json.new(Strata::Address)
  attribute :date_of_birth, :date

  attribute :payroll_accounts, :array, of: PayrollAccount.to_type
  attribute :activities, :array, of: Activity.to_type
  attribute :exemptions, :array, of: Exemption.to_type

  # Exclusion signals evaluated by ExclusionDeterminationService
  attribute :pregnancy_due_or_parturition_date, :date
  attribute :race_ethnicity, :string
  attribute :was_in_foster_care, :boolean, default: false
  attribute :currently_medically_frail, :boolean, default: false
  attribute :veteran_with_disability, :boolean, default: false
  attribute :dates_caretaking_infirm, :array, of: ActiveModel::Type::Date.new
  attribute :dependent_children_birth_dates, :array, of: ActiveModel::Type::Date.new
  attribute :meeting_tanf_or_snap_work, :boolean, default: false
  attribute :dates_in_drug_treatment, :array, of: ActiveModel::Type::Date.new
  attribute :dates_incarcerated, :array, of: ActiveModel::Type::Date.new

  # External-exception signals evaluated by ExceptionDeterminationService.
  # Distinct from exclusion/exemption signals above; see ExternalException.
  attribute :dates_receiving_inpatient_medical_care, :array, of: ActiveModel::Type::Date.new
  attribute :dates_in_declared_emergency_county, :array, of: ActiveModel::Type::Date.new
  attribute :dates_in_high_unemployment_county, :array, of: ActiveModel::Type::Date.new
  attribute :dates_traveling_for_medical_care, :array, of: ActiveModel::Type::Date.new
  attribute :dates_participating_in_other_program, :array, of: ActiveModel::Type::Date.new

  # The API-supplied exemption of +type+ that both applies and has been verified, or nil.
  # ExclusionDeterminationService and ExceptionDeterminationService read exemptions through here, so
  # the applies/verified filter lives in one place.
  def verified_exemption(type)
    Array(exemptions).find do |exemption|
      exemption.value && exemption.verification_status == "verified" && exemption.type&.to_sym == type.to_sym
    end
  end
end
