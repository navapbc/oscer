# frozen_string_literal: true

class Certifications::MemberData < Strata::ValueObject
  include ActiveModel::AsJsonAttributeType
  include Strata::Attributes

  class ContactData < Strata::ValueObject
    include ActiveModel::AsJsonAttributeType

    strata_attribute :email, :string
    strata_attribute :phone, :string # TODO: E.164 format, eventually would probably be more than one field, cell_phone, home_phone, etc
  end

  class Paycheck < Strata::ValueObject
    include ActiveModel::AsJsonAttributeType

    strata_attribute :period_start, :date # TODO: use Strata::DateRange?
    strata_attribute :period_end, :date
    strata_attribute :gross, :decimal # TODO: more like Strata::Money right?
    strata_attribute :net, :decimal # TODO: more like Strata::Money right?
    strata_attribute :hours_worked, :decimal

    validates :period_start, presence: true
    validates :period_end, presence: true
  end

  class PayrollAccount < Strata::ValueObject
    include ActiveModel::AsJsonAttributeType

    strata_attribute :company_name, :string
    strata_attribute :paychecks, ::ArrayType.new(of: Paycheck.to_type)
  end

  class Name < Strata::Name
    include ActiveModel::AsJsonAttributeType
    include ActiveRecord::AttributeMethods::BeforeTypeCast

    validates_with ActiveModel::Validations::AttributesTypeValidator
  end

  strata_attribute :account_email, :string
  strata_attribute :contact, ContactData.to_type
  strata_attribute :name, Name.to_type
  strata_attribute :date_of_birth, :date
  strata_attribute :race_ethnicity, :string

  strata_attribute :payroll_accounts, ::ArrayType.new(of: PayrollAccount.to_type)
  strata_attribute :pregnancy_status, :boolean, default: false
end
