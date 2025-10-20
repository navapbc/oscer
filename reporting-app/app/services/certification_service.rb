# frozen_string_literal: true

class CertificationService
  def find_cases_by_member_id(member_id)
    certifications_by_id = Certification.by_member_id(member_id).index_by(&:id)
    certification_cases = CertificationCase.where(certification_id: certifications_by_id.keys)
    certification_cases.each do |kase|
      kase.certification = certifications_by_id[kase.certification_id]
    end
    certification_cases
  end

  def fetch_open_actionable_cases
    hydrate_cases_with_certifications!(CertificationCase.open.actionable)
  end

  def fetch_closed_cases
    hydrate_cases_with_certifications!(CertificationCase.closed)
  end

  def fetch_cases(case_ids)
    hydrate_cases_with_certifications!(CertificationCase.find(case_ids))
  end

  def member_user(certification)
    email = certification.member_email
    if not email
      return
    end

    # TODO: filter to only verified emails and/or mfa enabled ones, etc
    User.find_by(email: email)
  end

  def certification_requirements_from_input(requirements_input)
    # if they've directly provided in a valid Certifications::Requirements, use it
    requirements = Certifications::Requirements.new_filtered(requirements_input)
    if requirements.valid?
      return requirements
    end

    # otherwise they've specified some combo of parameters we need to derive the
    # final Certification requirements from
    cert_type = requirements_input.fetch(:certification_type, nil)
    if cert_type
      type_params = self.certification_type_requirement_params(requirements_input.fetch(cert_type))
    end
    requirement_params = Certifications::RequirementParams.new_filtered(requirements_input.merge(type_params || {}))
    requirement_params.validate!

    requirement_params.to_requirements
  end

  def calculate_certification_requirements_for_type_input(certification_type_input)
    raise TypeError, "Expected instance of Api::Certifications::RequirementTypeInput" unless certification_type_input.is_a?(Api::Certifications::RequirementTypeInput)

    Certifications::RequirementParams.new_filtered(
      certification_type_input.attributes.merge(
        self.certification_type_requirement_params(certification_type_input.certification_type).attributes
      )
    ).to_requirements
  end

  def certification_type_requirement_params(certification_type)
    # TODO: can be updated to load from some config, the DB, etc.
    case certification_type
    when "new_application"
      Certifications::RequirementTypeParams.new({
        lookback_period: 1,
        number_of_months_to_certify: 1,
        due_period_days: 30
      })
    when "recertification"
      Certifications::RequirementTypeParams.new({
        lookback_period: 6,
        number_of_months_to_certify: 3,
        due_period_days: 30
      })
    end
  end

  private

  def hydrate_cases_with_certifications!(cases)
    certification_ids = cases.map(&:certification_id)
    certifications_by_id = Certification.where(id: certification_ids).index_by(&:id)
    cases.each do |kase|
      kase.certification = certifications_by_id[kase.certification_id]
    end
  end
end
