# frozen_string_literal: true

# Policy for InformationRequest access
#
# InformationRequests are tied to application forms, which are tied to certification cases.
# Staff can only view information requests for cases in their region.
class InformationRequestPolicy < StaffPolicy
  # Authorizes access to view a specific information request
  # Called by: authorize @information_request
  def show?
    staff_in_region?
  end

  private

  def in_region?
    # Get the certification_case_id through the application form
    application_form = record.application_form_type.constantize.find(record.application_form_id)
    certification_case_id = application_form.certification_case_id

    # Use CertificationCase.by_region scope to check if case is in user's region
    CertificationCase.by_region(user.region).where(id: certification_case_id).exists?
  end
end
