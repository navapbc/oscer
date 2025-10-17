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

    attribute :period_start, :date
    attribute :period_end, :date
    attribute :gross, :decimal # TODO more like Strata::Money right?
    attribute :net, :decimal # TODO more like Strata::Money right?
    attribute :hours_worked, :decimal
  end

  class PayrollAccount < ValueObject
    include ::JsonHash

    attribute :company_name, :string
    attribute :paychecks, :array, of: Paycheck.to_type
  end

  class Name < ValueObject
    include ::JsonHash

    attribute :first, :string
    attribute :middle, :string
    attribute :last, :string
    attribute :suffix, :string

    def self.from_strata(strata_name)
      raise TypeError, "expected a Strata::Name instance" unless strata_name.is_a?(Strata::Name)
      self.new(strata_name.attributes)
    end

    def to_strata
      Strata::Name.new(self.attributes)
    end
  end

  attribute :account_email, :string
  attribute :contact, ContactData.to_type
  attribute :name, Name.to_type

  attribute :payroll_accounts, :array, of: PayrollAccount.to_type
end
