# frozen_string_literal: true

class ExemptionDeterminationService
  class << self
    # Called by CertificationBusinessProcess at EX_PARTE_EXEMPTION_CHECK step
    # Service handles: evaluation, recording via model, and publishing events
    # Business process handles: transitions and notifications
    # @param kase [CertificationCase]
    def determine(kase)
      certification = Certification.find(kase.certification_id)
      eligibility_fact = evaluate_exemption_eligibility(certification)

      if eligibility_fact.value
        kase.record_exemption_determination(eligibility_fact)
        Strata::EventManager.publish("DeterminedExempt", { case_id: kase.id, certification_id: kase.certification_id })
      else
        Strata::EventManager.publish("DeterminedNotExempt", { case_id: kase.id, certification_id: kase.certification_id })
      end
    end

    private

    def evaluate_exemption_eligibility(certification)
      ruleset = Rules::ExemptionRuleset.new
      engine = Strata::RulesEngine.new(ruleset)

      evaluation_date = extract_evaluation_date(certification)
      date_of_birth = extract_date_of_birth(certification)
      pregnancy_status = extract_pregnancy_status(certification)
      race_ethnicity = extract_race_ethnicity(certification)
      veteran_disability_rating = extract_veteran_disability_status(certification)

      engine.set_facts(
        date_of_birth: date_of_birth,
        evaluated_on: evaluation_date,
        pregnancy_status: pregnancy_status,
        race_ethnicity: race_ethnicity,
        veteran_disability_rating: veteran_disability_rating
      )

      engine.evaluate(:eligible_for_exemption)
    end

    def extract_evaluation_date(certification)
      return nil unless certification.certification_requirements

      certification.certification_requirements.certification_date
    end

    def extract_date_of_birth(certification)
      return nil unless certification.member_data

      certification.member_data.date_of_birth
    end

    def extract_pregnancy_status(certification)
      return nil unless certification.member_data

      certification.member_data.pregnancy_status
    end

    def extract_race_ethnicity(certification)
      return nil unless certification.member_data

      certification.member_data.race_ethnicity
    end

    def extract_veteran_disability_status(certification)
      return nil unless certification.member_data&.va_icn.present?

      VeteranDisabilityService.new.get_disability_rating(icn: certification.member_data.va_icn)
    end
  end
end
