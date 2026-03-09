# frozen_string_literal: true

class StagedDocumentPolicy < ApplicationPolicy
  def create?
    user
  end

  def lookup?
    user
  end

  private

  def owner?
    record.user_id == user.id
  end
end
