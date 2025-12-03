# frozen_string_literal: true

module Staff
  class UsersController < StaffController
    before_action :set_user, only: [ :show, :edit, :update ]

    def index
      # TODO: grab only users that have a role
      @users = User.all
    end
  end
end
