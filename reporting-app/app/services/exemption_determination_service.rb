# frozen_string_literal: true

class ExemptionDeterminationService
  class << self
    def determine!(kase)
      certification = Certification.find(kase.certification_id)

      if eligible_for_exemption?(certification)
        ActiveRecord::Base.transaction do
          kase.exemption_request_approval_status = "approved"
          kase.exemption_request_approval_status_updated_at = Time.current
          kase.close
        end

        Strata::EventManager.publish("DeterminedExempt", { case_id: kase.id })
      else
        Strata::EventManager.publish("DeterminedRequirementsNotMet", { case_id: kase.id })
      end
    end

    private

    def eligible_for_exemption?(certification)
      date_of_birth = extract_date_of_birth(certification)
      return false unless date_of_birth

      age = calculate_age(date_of_birth)
      age < 19 || age >= 65
    end

    def extract_date_of_birth(certification)
      return nil unless certification.member_data

      dob_string = certification.member_data.dig("date_of_birth")
      return nil if dob_string.blank?

      Date.parse(dob_string)
    rescue Date::Error
      nil
    end

    def calculate_age(date_of_birth)
      today = Date.current
      age = today.year - date_of_birth.year
      age -= 1 if (today.month < date_of_birth.month) || (today.month == date_of_birth.month && today.day < date_of_birth.day)
      age
    end
  end
end
