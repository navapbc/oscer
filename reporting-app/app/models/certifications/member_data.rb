# frozen_string_literal: true

class Certifications::MemberDataContactData < ValueObject
  include ::JsonHash

  attribute :email, :string
  attribute :phone, :string
end

class Certifications::MemberData < ValueObject
  include ::JsonHash

  attribute :account_email, :string
  attribute :contact, Certifications::MemberDataContactData.to_type
end
