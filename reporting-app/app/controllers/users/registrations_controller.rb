# frozen_string_literal: true

# freeze_string_literal: true

class Users::RegistrationsController < ApplicationController
  layout "users"
  skip_after_action :verify_authorized

  def new
    @form = Users::RegistrationForm.new()
    render :new
  end

  def create
    @form = Users::RegistrationForm.new(registration_params)

    if @form.invalid?
      flash.now[:errors] = @form.errors.full_messages
      return render :new, status: :unprocessable_entity
    end

    begin
      auth_service.register(@form.email, @form.password)
    rescue Auth::Errors::BaseAuthError => e
      flash.now[:errors] = [ e.message ]
      return render :new, status: :unprocessable_entity
    end

    redirect_to users_verify_account_path
  end

  def new_account_verification
    @form = Users::VerifyAccountForm.new()
    @resend_verification_form = Users::ResendVerificationForm.new(email: @form.email)
  end

  def create_account_verification
    @form = Users::VerifyAccountForm.new(verify_account_params)
    @resend_verification_form = Users::ResendVerificationForm.new(email: @form.email)

    if @form.invalid?
      flash.now[:errors] = @form.errors.full_messages
      return render :new_account_verification, status: :unprocessable_entity
    end

    begin
      auth_service.verify_account(@form.email, @form.code)
    rescue Auth::Errors::BaseAuthError => e
      flash.now[:errors] = [ e.message ]
      return render :new_account_verification, status: :unprocessable_entity
    end

    redirect_to new_user_session_path
  end

  def resend_verification_code
    email = params[:users_resend_verification_form][:email]
    @resend_verification_form = Users::ResendVerificationForm.new(email: email)

    if @resend_verification_form.invalid?
      flash.now[:errors] = @resend_verification_form.errors.full_messages
      return render :new_account_verification, status: :unprocessable_entity
    end

    auth_service.resend_verification_code(email)

    flash[:notice] = I18n.t("users.registrations.new_account_verification.resend_success")
    redirect_to users_verify_account_path
  end

  private
    def auth_service
      AuthService.new
    end

    def registration_params
      params.require(:users_registration_form).permit(:email, :password, :password_confirmation, :spam_trap)
    end

    def verify_account_params
      params.require(:users_verify_account_form).permit(:email, :code)
    end
end
