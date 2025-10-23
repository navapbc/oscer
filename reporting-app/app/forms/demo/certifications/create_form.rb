# frozen_string_literal: true

module Demo
  module Certifications
    class CreateForm < BaseCreateForm
      EX_PARTE_SCENARIO_OPTIONS = [ "No data", "Partially met work hours requirement", "Fully met work hours requirement" ]

      attribute :ex_parte_scenario, :enum, options: EX_PARTE_SCENARIO_OPTIONS

      def self.new_for_certification_type(certification_type)
        certification_requirement_params = ::Certifications::RequirementTypeParams.cert_type_params_for(certification_type) || {}
        Demo::Certifications::CreateForm.new({ certification_type: certification_type }.merge(certification_requirement_params.as_json))
      end

      def to_certification
        certification_requirements = ::Certifications::RequirementParams.new_filtered(self.attributes.with_indifferent_access).to_requirements

        member_data = {
          "name": self.member_name
        }

        case self.ex_parte_scenario
        when "Partially met work hours requirement"
          member_data.merge!(FactoryBot.build(:certification_member_data, :partially_met_work_hours_requirement, cert_date: self.certification_date).attributes.compact)
        when "Fully met work hours requirement"
          member_data.merge!(FactoryBot.build(:certification_member_data, :fully_met_work_hours_requirement, cert_date: self.certification_date, num_months: self.number_of_months_to_certify).attributes.compact)
        else
          # nothing
        end

        @certification = FactoryBot.build(
          :certification,
          :connected_to_email,
          email: self.member_email,
          case_number: self.case_number,
          certification_requirements: certification_requirements,
          member_data: ::Certifications::MemberData.new(member_data),
        )
      end
    end
  end
end
