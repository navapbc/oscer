# frozen_string_literal: true

# Policy for CertificationCase access
#
# This policy is used for:
# 1. Authorizing access to individual certification case records (show?, update?)
# 2. Scoping queries to filter cases by region (Scope class)
#
# Note: Collection actions (index, closed) use StaffPolicy for page-level authorization
# via the controller's `authorize :staff` before_action.
class CertificationCasePolicy < StaffPolicy
  # Authorizes access to view a specific certification case
  # Called by: authorize @case
  def show?
    staff_in_region?
  end

  # Scopes certification cases to only show records from the user's region
  # Called by: policy_scope(CertificationCase)
  class Scope < StaffPolicy::Scope
    def resolve
      return scope.none unless user.staff?

      scope.by_region(user.region)
    end
  end

  private

  def in_region?
    Certification.by_region(user.region).where(id: record.certification_id).exists?
  end

  def staff_in_region?
    staff? && in_region?
  end
end
