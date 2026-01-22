# frozen_string_literal: true

class CertificationPolicy < ApplicationPolicy
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
    def resolve
      scope.all
    end
  end

  delegate :staff?, to: :user
  delegate :state_system?, to: :user
end
