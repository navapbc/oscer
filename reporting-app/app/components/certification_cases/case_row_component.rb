# frozen_string_literal: true

class CertificationCases::CaseRowComponent < Strata::Cases::CaseRowComponent
  def self.columns
    [ :name ] + super
  end

  protected

  def name
    link_to @case.certification.member_name_strata&.full_name, member_path(@case.certification.member_id)
  end

  # Override default behavior to show the case number from the
  # certification request rather than the case.id UUID
  def case_no
    link_to @case.certification.case_number, certification_case_path(@case)
  end

  def step
    step_name = @case.business_process_instance.current_step
    t(".steps.#{step_name}")
  end
end
