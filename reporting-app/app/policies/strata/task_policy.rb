# frozen_string_literal: true

module Strata
  # Policy for Strata::Task access
  # Inherits from StaffPolicy to ensure staff-only access
  class TaskPolicy < ::StaffPolicy
    # Custom actions for TasksController
    def assign?
      staff?
    end

    def request_information?
      staff?
    end

    def create_information_request?
      staff?
    end

    class Scope < ::StaffPolicy::Scope
      def resolve
        # TODO: Restrict scope based on caseworker's region
        # https://github.com/navapbc/oscer/issues/60
        user.staff? ? scope.all : scope.none
      end
    end
  end
end
