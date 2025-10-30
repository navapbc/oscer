# frozen_string_literal: true

class Users::AccountsController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :verify_authorized

  def edit
    @email_form = Users::UpdateEmailForm.new({ email: current_user.email })
    @password_form = Users::ForgotPasswordForm.new({ email: current_user.email })
  end

  def update_email
    @email_form = Users::UpdateEmailForm.new(user_email_params)

    if @email_form.invalid?
      flash.now[:errors] = @email_form.errors.full_messages
      return render :edit, status: :unprocessable_entity
    end

    begin
      auth_service.change_email(current_user.uid, @email_form.email)
    rescue Auth::Errors::BaseAuthError => e
      flash.now[:errors] = [ e.message ]
      return render :edit, status: :unprocessable_entity
    end

    redirect_to({ action: :edit }, notice: "Account updated successfully.")
  end

  private
    def auth_service
      AuthService.new
    end

    def user_email_params
      params.require(:users_update_email_form).permit(:email)
    end
end
