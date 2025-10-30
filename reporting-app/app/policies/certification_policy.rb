# frozen_string_literal: true

class CertificationPolicy < ApplicationPolicy
  def initialize(user, record)
    # TODO: for demo purposes at the moment allow unauthenticated, but at some
    # point that will change
    # raise Pundit::NotAuthorizedError, "must be logged in" unless user
    @user = user
    @record = record
  end

  def index?
    staff? || state_system?
  end

  def show?
    staff? || state_system?
  end

  def create?
    staff? || state_system?
  end

  def update?
    staff? || state_system?
  end

  def destroy?
    false
  end

  class Scope < ApplicationPolicy::Scope
    def initialize(user, scope)
      # TODO: for demo purposes at the moment allow unauthenticated, but at some
      # point that will change
      # raise Pundit::NotAuthorizedError, "must be logged in" unless user
      @user = user
      @scope = scope
    end

    def resolve
      scope.all
    end
  end

  private

  def staff?
    # TODO: once we have user types
    true
  end

  def state_system?
    # TODO: once we have user types
    true
  end
end
