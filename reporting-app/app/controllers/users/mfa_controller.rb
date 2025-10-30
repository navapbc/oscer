# frozen_string_literal: true

# https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-mfa-totp.html#totp-mfa-set-up-api
class Users::MfaController < ApplicationController
  before_action :authenticate_user!
  skip_after_action :verify_authorized

  # Initial page a user is shown after creating an account
  def preference
    @form = Users::MfaPreferenceForm.new
  end

  def update_preference
    @form = Users::MfaPreferenceForm.new(params.fetch(:users_mfa_preference_form, {}).permit(:mfa_preference))

    if @form.invalid?
      flash.now[:errors] = @form.errors.full_messages
      return render :preference, status: :unprocessable_entity
    end

    if @form.mfa_preference == "software_token"
      redirect_to action: :new
      return
    end

    current_user.update!(mfa_preference: @form.mfa_preference)
    redirect_to after_sign_in_path_for(current_user)
  end

  # Associate an authenticator app
  def new
    # We need the access token in order to complete the MFA-setup process,
    # so we make sure it's still fresh. If it's not, we get a fresh one by
    # forcing the user to log in again
    if current_user.access_token_expires_within_minutes?(current_user.access_token, 5)
      sign_out(current_user)
      redirect_to new_user_session_path
      return
    end

    @form = Users::AssociateMfaForm.new
    @secret_code = auth_service.associate_software_token(current_user.access_token)
    @email = current_user.email
  end

  def create
    @form = Users::AssociateMfaForm.new(
      temporary_code: params[:users_associate_mfa_form][:temporary_code]
    )

    if @form.invalid?
      return redirect_to({ action: :new }, flash: { errors: @form.errors.full_messages })
    end

    begin
      auth_service.verify_software_token(@form.temporary_code, current_user)
    rescue Auth::Errors::BaseAuthError => e
      return redirect_to({ action: :new }, flash: { errors: [ e.message ] })
    end

    redirect_to root_path, { notice: I18n.t("users.mfa.create.success") }
  end

  def destroy
    auth_service.disable_software_token(current_user)
    redirect_to users_account_path, notice: I18n.t("users.accounts.edit.mfa_successfully_disabled")
  end

  private

    def auth_service
      AuthService.new
    end
end
