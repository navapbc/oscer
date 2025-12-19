# frozen_string_literal: true

module Strata
  # Policy for Strata::Task access
  #
  # This policy is used for:
  # 1. Page-level authorization for task actions (index?, assign?, etc.)
  # 2. Authorizing access to individual task records (show?, update?)
  # 3. Scoping queries to filter tasks by region (Scope class)
  class TaskPolicy < ::StaffPolicy
    # Collection/page-level actions - any staff can access
    def index?
      staff?
    end

    def pick_up_next_task?
      staff?
    end

    # Individual task actions - must be in same region
    def show?
      staff_in_region?
    end

    def update?
      staff_in_region?
    end

    def assign?
      staff_in_region?
    end

    def request_information?
      staff_in_region?
    end

    def create_information_request?
      staff_in_region?
    end

    # Scopes tasks to only show records from the user's region
    # Called by: policy_scope(Strata::Task)
    class Scope < ::StaffPolicy::Scope
      def resolve
        return scope.none unless user&.staff?

        scope.by_region(user.region)
      end
    end

    private

    def in_region?
      user.region == ::TaskService.get_region_for_task(record)
    end

    def staff_in_region?
      staff? && in_region?
    end
  end
end
