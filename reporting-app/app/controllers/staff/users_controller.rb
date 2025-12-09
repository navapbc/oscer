# frozen_string_literal: true

module Staff
  class UsersController < StaffController
    after_action :verify_authorized # TODO: Move to StaffController in follow-up PR

    def index
      authorize :admin
      @users = User.staff_members
    end
  end
end
