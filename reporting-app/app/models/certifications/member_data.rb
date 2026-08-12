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

  class Activity < ValueObject
    include ActiveModel::AsJsonAttributeType

    TYPE_HOURLY = "hourly"
    TYPE_INCOME = "income"
    ACTIVITY_TYPES = [ TYPE_HOURLY, TYPE_INCOME ].freeze
    CATEGORY_EDUCATION = "education"
    VERIFIED = "verified"
    VERIFICATION_STATUSES = [ VERIFIED, "self_attested", "pending" ].freeze

    # One credit hour is 12.99 clock hours per month (3 hours per week over a 4.33 week month)
    # per the Federal Register.
    CREDIT_HOURS_MULTIPLIER = BigDecimal("12.99")

    attribute :type, :string
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

    validates :type, presence: true, inclusion: { in: ACTIVITY_TYPES }
    validates :category, presence: true, inclusion: { in: ::Activity::ALLOWED_CATEGORIES }
    validates :hours, presence: true, if: -> { type == TYPE_HOURLY && !education_credit_hours? }
    validates :credit_hours, numericality: { greater_than: 0 }, allow_nil: true
    validates :credit_hours, absence: true, unless: -> { type == TYPE_HOURLY && category == CATEGORY_EDUCATION }
    validates :gross_income, presence: true,
                             numericality: { greater_than: 0 },
                             if: -> { type == TYPE_INCOME }
    validates :source,
              presence: true,
              inclusion: { in: ExternalIncomeActivity::SOURCE_TYPES.values },
              if: -> { type == TYPE_INCOME }
    validates :period_start, presence: true
    validates :period_end, presence: true
    validates :verification_status, presence: true, inclusion: { in: VERIFICATION_STATUSES }

    # Only verified activities count toward a certification.
    def verified?
      verification_status == VERIFIED
    end

    # Education activities may report credit hours in place of clock hours.
    def education_credit_hours?
      category == CATEGORY_EDUCATION && credit_hours.present?
    end

    # Reported hours, or their credit-hour equivalent when hours were omitted.
    def clock_hours
      return hours if hours.present?

      credit_hours * CREDIT_HOURS_MULTIPLIER if education_credit_hours?
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
