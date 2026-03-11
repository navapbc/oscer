# frozen_string_literal: true

class StagedDocumentPolicy < ApplicationPolicy
  def create?
    user
  end

  def lookup?
    user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
