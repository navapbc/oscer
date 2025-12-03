# frozen_string_literal: true

module Staff
  class UsersController < StaffController
    before_action :set_user, only: [:show, :edit, :update]

    def index
      @users = User.all
    end

    def show
    end

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to "/staff/users/#{@user.id}", notice: 'User was successfully updated.'
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:roles, :program, :region)
    end
  end
end

