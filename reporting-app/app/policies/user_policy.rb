# frozen_string_literal: true

# Policy for User access
# Inherits from StaffPolicy to ensure staff-only access
class UserPolicy < StaffPolicy
  class Scope < StaffPolicy::Scope
    def resolve
      # Admin users can see all users
      user.admin? ? scope.all : scope.none
    end
  end
end
