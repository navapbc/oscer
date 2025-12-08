# frozen_string_literal: true

# Policy for staff-only access to controllers
# Allows users with "admin" or "caseworker" roles
class StaffPolicy < ApplicationPolicy
  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    staff?
  end

  def show?
    staff?
  end

  def create?
    staff?
  end

  def new?
    create?
  end

  def update?
    staff?
  end

  def edit?
    update?
  end

  def destroy?
    staff?
  end

  def search?
    staff?
  end

  private

  class Scope < ApplicationPolicy::Scope
    def resolve
      # TODO: Restrict scope based on caseworker's region
      # https://github.com/navapbc/oscer/issues/60
      # https://github.com/navapbc/oscer/issues/61
      scope.all
    end
  end

  delegate :staff?, to: :user
end
