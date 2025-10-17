# frozen_string_literal: true

class Certifications::MemberDataContactData < ValueObject
  include ::JsonHash

  attribute :email, :string
  attribute :phone, :string # TODO: E.164 format, eventually would probably be more than one field, cell_phone, home_phone, etc
end

class Certifications::MemberDataPaycheck < ValueObject
  include ::JsonHash

  attribute :period_start, :date
  attribute :period_end, :date
  attribute :gross, :decimal # TODO more like Strata::Money right?
  attribute :net, :decimal # TODO more like Strata::Money right?
  attribute :hours_worked, :decimal
end

class Certifications::MemberDataPayrollAccount < ValueObject
  include ::JsonHash

  attribute :company_name, :string
  attribute :paychecks, :array, of: Certifications::MemberDataPaycheck.to_type
end

class Certifications::MemberDataName < ValueObject
  include ::JsonHash

  attribute :first, :string
  attribute :middle, :string
  attribute :last, :string
  attribute :suffix, :string
end

class Certifications::MemberData < ValueObject
  include ::JsonHash

  attribute :account_email, :string
  attribute :contact, Certifications::MemberDataContactData.to_type
  attribute :name, Certifications::MemberDataName.to_type

  attribute :payroll_accounts, :array, of: Certifications::MemberDataPayrollAccount.to_type
end
