# frozen_string_literal: true

# Policy for CertificationCase access
# Inherits from StaffPolicy to ensure staff-only access
class CertificationCasePolicy < StaffPolicy
  class Scope < StaffPolicy::Scope
    def resolve
      # TODO: Restrict scope based on caseworker's region
      # https://github.com/navapbc/oscer/issues/61
      user.staff? ? scope.all : scope.none
    end
  end
end
