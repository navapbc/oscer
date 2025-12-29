# frozen_string_literal: true

class TaskPolicy < Strata::TaskPolicy
  def index?
    staff?
  end

  def show?
    staff_in_region?
  end

  def update?
    staff_in_region?
  end

  def pick_up_next_task?
    staff?
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

  class Scope < Strata::TaskPolicy::Scope
    def resolve
      return scope.none unless user&.staff?

      scope.by_region(user.region)
    end
  end

  private

  def in_region?
    user.region == TaskService.get_region_for_task(record)
  end
end
