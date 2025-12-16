# frozen_string_literal: true

# Policy for CertificationCase access
# Inherits from StaffPolicy to ensure staff-only access
class CertificationCasePolicy < StaffPolicy
  class Scope < StaffPolicy::Scope
    def resolve
      return scope.none unless user&.staff?

      scope.by_region(user.region)
    end
  end
end
