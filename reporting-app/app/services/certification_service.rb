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

  def find(case_id, hydrate: true)
    kase = CertificationCase.find(case_id)
    if hydrate
      hydrate_cases_with_certifications!([ kase ])
    end
    kase
  end

  def fetch_open_actionable_cases
    hydrate_cases_with_certifications!(CertificationCase.open.actionable)
  end

  def fetch_open_cases
    hydrate_cases_with_certifications!(CertificationCase.open)
  end

  def fetch_closed_cases
    hydrate_cases_with_certifications!(CertificationCase.closed)
  end

  def fetch_cases(case_ids)
    hydrate_cases_with_certifications!(CertificationCase.find(case_ids))
  end

  def fetch_cases_by_certification_ids(certification_ids)
    cases = CertificationCase.where(certification_id: certification_ids)
    hydrate_cases_with_certifications!(cases)
    cases
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
    requirement_params = Certifications::RequirementParams.new_filtered(requirements_input)
    requirement_params.validate!

    requirement_params.to_requirements
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
