# frozen_string_literal: true

class CertificationBatchUploadPolicy < AdminPolicy
  def create?
    api_client? || admin?
  end

  def new?
    admin?
  end

  def show?
    api_client? || admin?
  end

  def process_batch?
    update?
  end

  def results?
    admin?
  end

  def download_errors?
    admin?
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if user.respond_to?(:admin?) && user.admin?
        scope.all
      elsif user.respond_to?(:state_system?) && user.state_system?
        scope.where(source_type: :api)
      else
        scope.none
      end
    end
  end

  private

  def api_client?
    user.respond_to?(:state_system?) && user.state_system?
  end
end
