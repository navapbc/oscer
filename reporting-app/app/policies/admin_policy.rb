# frozen_string_literal: true

class AdminPolicy < ApplicationPolicy
  def admin?
    user.role == "admin"
  end

  def index?
    admin?
  end

  def show?
    admin?
  end

  def create?
    admin?
  end

  def new?
    create?
  end

  def update?
    admin?
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def resolve
      scope.all if admin?
    end
  end
end
