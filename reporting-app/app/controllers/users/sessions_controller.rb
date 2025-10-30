# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  layout "users"
  skip_after_action :verify_authorized

  def new
    @form = Users::NewSessionForm.new
  end

  def create
    @form = Users::NewSessionForm.new(new_session_params)

    if @form.invalid?
      flash.now[:errors] = @form.errors.full_messages
      return render :new, status: :unprocessable_entity
    end

    begin
      response = auth_service.initiate_auth(
        @form.email,
        @form.password
      )
    rescue Auth::Errors::UserNotConfirmed => e
      return redirect_to users_verify_account_path
    rescue Auth::Errors::BaseAuthError => e
      flash.now[:errors] = [ e.message ]
      return render :new, status: :unprocessable_entity
    end

    unless response[:user].present?
      puts response.inspect
      session[:challenge_session] = response[:session]
      session[:challenge_email] = @form.email
      return redirect_to session_challenge_path
    end

    auth_user(response[:user], response[:access_token])
  end

  # Show MFA
  def challenge
    if session[:challenge_session].nil?
      return redirect_to new_user_session_path
    end

    @form = Users::AuthAppCodeForm.new
  end

  # Submit MFA
  def respond_to_challenge
    @form = Users::AuthAppCodeForm.new(params.require(:users_auth_app_code_form).permit(:code))

    if @form.invalid?
      flash.now[:errors] = @form.errors.full_messages
      return render :challenge, status: :unprocessable_entity
    end

    begin
      response = auth_service.respond_to_auth_challenge(
        @form.code, {
          session: session[:challenge_session],
          email: session[:challenge_email]
        }
      )
    rescue Auth::Errors::BaseAuthError => e
      flash.now[:errors] = [ e.message ]
      return render :challenge, status: :unprocessable_entity
    end

    unless response[:user].present?
      flash.now[:errors] = [ "Invalid code" ]
      return render :challenge, status: :unprocessable_entity
    end

    session[:challenge_session] = nil
    session[:challenge_email] = nil

    auth_user(response[:user], response[:access_token])
  end

  # Optionally, you can override the default sign out before:
  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  private

    def auth_service
      AuthService.new
    end

    def new_session_params
      # If :users_new_session_form is renamed, make sure to also update it in
      # auth_service_authenticatable.rb otherwise login will not work.
      params.require(:users_new_session_form).permit(:email, :password, :spam_trap)
    end

    # This is similar to the default Devise SessionController implementation
    # but bypasses warden.authenticate! since we are doing that through Cognito
    # https://www.rubydoc.info/github/plataformatec/devise/Devise/SessionsController
    def auth_user(user, access_token)
      user.access_token = access_token
      sign_in(user)
      respond_with user, location: after_sign_in_path_for(user)
    end
end
