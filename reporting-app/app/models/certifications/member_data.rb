# frozen_string_literal: true

class Certifications::MemberDataContactData
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON
  include ActiveModel::NewFiltered

  attribute :email, :string
  attribute :phone, :string
end

class Certifications::MemberDataContactDataType < ActiveRecord::Type::Json
  def cast(value)
    return nil if value.nil?

    return value if value.is_a?(Certifications::MemberDataContactData)

    case value
    when Hash
      Certifications::MemberDataContactData.new(value)
    else
      nil
    end
  end
end

class Certifications::MemberData
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serializers::JSON
  include ActiveModel::NewFiltered

  attribute :account_email, :string
  attribute :contact, Certifications::MemberDataContactDataType.new
end

class Certifications::MemberDataType < ActiveRecord::Type::Json
  def cast(value)
    return nil if value.nil?

    return value if value.is_a?(Certifications::MemberData)

    case value
    when Hash
      Certifications::MemberData.new(value)
    else
      nil
    end
  end
end
