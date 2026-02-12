# frozen_string_literal: true

module Demo
  module Certifications
    class CreateForm < BaseCreateForm
      EX_PARTE_SCENARIO_OPTIONS = [
        "No data", "Partially met work hours requirement", "Fully met work hours requirement",
        "Meets age-based exemption requirement"
      ].freeze

      attribute :ex_parte_scenario, :enum, options: EX_PARTE_SCENARIO_OPTIONS

      def self.new_for_certification_type(certification_type)
        certification_requirement_params = ::Certifications::RequirementTypeParams.cert_type_params_for(certification_type) || {}
        Demo::Certifications::CreateForm.new({ certification_type: certification_type }.merge(certification_requirement_params.as_json))
      end

      def to_certification
        certification_requirement_params = ::Certifications::RequirementParams.new_filtered(attributes.with_indifferent_access)
        # shouldn't be possible, but we need to ensure the params are valid in
        # order to construct the requirements next
        if certification_requirement_params.invalid?
          errors.merge!(certification_requirement_params.errors)
          return false
        end

        certification_requirements = certification_requirement_params.to_requirements
        if certification_requirements.invalid?
          errors.merge!(certification_requirements.errors)
          return false
        end

        member_data = {}

        case ex_parte_scenario
        when "Partially met work hours requirement"
          member_data.merge!(
            FactoryBot.build(
              :certification_member_data, :partially_met_work_hours_requirement, cert_date: certification_date
            ).attributes.compact
          )
        when "Fully met work hours requirement"
          member_data.merge!(
            FactoryBot.build(
              :certification_member_data, :fully_met_work_hours_requirement, cert_date: certification_date, num_months: number_of_months_to_certify
            ).attributes.compact)
        when "Meets age-based exemption requirement"
          member_data.merge!(
            FactoryBot.build(
              :certification_member_data, :meets_age_based_exemption_requirement, cert_date: certification_date
            ).attributes.compact
          )
        end

        member_data = ::Certifications::MemberData.new(member_data).tap do |md|
          md.name = member_name if member_name.present?
          md.date_of_birth = date_of_birth if date_of_birth.present?
          md.pregnancy_status = pregnancy_status if pregnancy_status.present?
          md.race_ethnicity = race_ethnicity if race_ethnicity.present?
          md.va_icn = va_icn if va_icn.present?
        end

        @certification = FactoryBot.build(
          :certification,
          :connected_to_email,
          email: member_email,
          case_number: case_number,
          certification_requirements: certification_requirements,
          member_data: member_data,
        )
      end
    end
  end
end
