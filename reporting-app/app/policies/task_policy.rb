# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
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

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope
      .joins("INNER JOIN certification_cases ON certification_cases.id = strata_tasks.case_id")
      .joins("INNER JOIN certifications ON certifications.id = certification_cases.certification_id")
      .where("certifications.certification_requirements->>'region' = ?", user.region) 
    end
  end

  private

  def staff?
    user.staff?
  end

  def in_region?
    user.region == TaskService.get_region_for_task(record)
  end

  def staff_in_region?
    staff? && in_region?
  end
end