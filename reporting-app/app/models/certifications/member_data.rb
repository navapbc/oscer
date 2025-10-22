# frozen_string_literal: true

class Certifications::MemberData < ValueObject
  include ::JsonHash

  class ContactData < ValueObject
    include ::JsonHash

    attribute :email, :string
    attribute :phone, :string # TODO: E.164 format, eventually would probably be more than one field, cell_phone, home_phone, etc
  end

  class Paycheck < ValueObject
    include ::JsonHash

    attribute :period_start, :date # TODO: use Strata::DateRange?
    attribute :period_end, :date
    attribute :gross, :decimal # TODO: more like Strata::Money right?
    attribute :net, :decimal # TODO: more like Strata::Money right?
    attribute :hours_worked, :decimal

    validates :period_start, presence: true
    validates :period_end, presence: true
  end

  class PayrollAccount < ValueObject
    include ::JsonHash

    attribute :company_name, :string
    attribute :paychecks, :array, of: Paycheck.to_type
  end

  attribute :account_email, :string
  attribute :contact, ContactData.to_type
  attribute :name, JsonType.new.set_type(Strata::Name)

  attribute :payroll_accounts, :array, of: PayrollAccount.to_type
end
