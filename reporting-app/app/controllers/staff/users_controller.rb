# frozen_string_literal: true

module Staff
  class UsersController < StaffController
    def index
      @users = User.staff_members
    end
  end
end
