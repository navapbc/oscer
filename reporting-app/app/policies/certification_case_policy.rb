# frozen_string_literal: true

# Policy for CertificationCase access
# Inherits from StaffPolicy to ensure staff-only access
class CertificationCasePolicy < StaffPolicy
  def index?
    staff_in_region?
  end

  def show?
    staff_in_region?
  end

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
