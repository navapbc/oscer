# frozen_string_literal: true

FactoryBot.define do
  factory :certification do
    id { SecureRandom.uuid }
    member_id { Faker::NationalHealthService.british_number }
    case_number { "C-%d" % Faker::Number.within(range: 1..10000) }
    certification_requirements { build(:certification_certification_requirements) }
    member_data { build(:certification_member_data) }

    trait :invalid_json_data do
      certification_requirements { "()" }
      member_data { "()" }
    end

    trait :connected_to_email do
      transient do
        email { nil }
      end

      after(:build) do |cert, context|
        if not context.email.blank?
          cert.member_data = Certifications::MemberData.new_filtered(cert.member_data.attributes.deep_merge({
            "account_email": context.email,
            "contact": {
              "email": context.email,
              "phone": Faker::PhoneNumber.cell_phone_in_e164
            }
        }))
        end
      end
    end
  end
end
