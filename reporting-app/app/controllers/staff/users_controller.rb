# frozen_string_literal: true

module Staff
  class UsersController < AdminController
    def index
      @users = policy_scope(User.staff_members, policy_scope_class: AdminPolicy::Scope)
    end
  end
end
