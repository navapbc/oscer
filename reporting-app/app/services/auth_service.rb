# frozen_string_literal: true

class AuthService
  def initialize(auth_adapter = nil)
    @auth_adapter = auth_adapter || default_adapter
  end

  def default_adapter
    auth_service = Rails.application.config.auth_adapter

    case auth_service
    when "cognito"
      Auth::CognitoAdapter.new
    when "mock"
      Auth::MockAdapter.new
    else
      raise "Unsupported AUTH_SERVICE: #{auth_service}"
    end
  end

  # Send a confirmation code that's required to change the user's password
  def forgot_password(email)
    @auth_adapter.forgot_password(email)
  end

  def confirm_forgot_password(email, code, password)
    @auth_adapter.confirm_forgot_password(email, code, password)
  end

  def change_email(uid, new_email)
    @auth_adapter.change_email(uid, new_email)

    user = User.find_by(uid: uid)
    user.update!(email: new_email)
  end

  # Initiate a login for the user. The response will indicate whether the user
  # has additional steps, like multi-factor auth, to complete the login.
  def initiate_auth(email, password)
    response = @auth_adapter.initiate_auth(email, password)
    handle_auth_result(response, email)
  end

  # Respond to a multi-factor auth challenge
  def respond_to_auth_challenge(code, challenge = {})
    response = @auth_adapter.respond_to_auth_challenge(code, challenge)
    handle_auth_result(response, challenge[:email])
  end

  def register(email, password)
    # @TODO: Handle errors from the auth service, like when the email is already taken
    # See https://github.com/navapbc/template-application-rails/issues/15
    account = @auth_adapter.create_account(email, password)

    create_db_user(account[:uid], email, account[:provider])
  end

  # Verify the code sent to the user as part of their initial sign up process.
  # This needs done before they can log in.
  def verify_account(email, code)
    @auth_adapter.verify_account(email, code)
  end

  # Resend the code used for verifying the user's email address
  def resend_verification_code(email)
    @auth_adapter.resend_verification_code(email)
  end

  # Initiate the process of enabling authenticator-app MFA
  def associate_software_token(access_token)
    @auth_adapter.associate_software_token(access_token)
  end

  # Complete the process of enabling authenticator-app MFA
  def verify_software_token(code, user)
    @auth_adapter.verify_software_token(code, user.access_token)
    user.update!(mfa_preference: "software_token")
  end

  # Disable authenticator-app MFA for the user
  def disable_software_token(user)
    @auth_adapter.disable_software_token(user.uid)
    user.update!(mfa_preference: "opt_out")
  end

  private

    def create_db_user(uid, email, provider)
      Rails.logger.info "Creating User uid: #{uid}"

      user = User.create!(
        uid: uid,
        email: email,
        provider: provider,
      )
      user
    end

    def handle_auth_result(response, email)
      unless response[:uid]
        return response
      end

      user = User.find_by(uid: response[:uid])

      if user.nil?
        user = create_db_user(
          response[:uid],
          email,
          response[:provider]
        )
      elsif user.email != email
        # If the user's email changed outside of our system, then sync the changes
        user.update!(email: email)
      end

      {
        access_token: response[:access_token],
        user: user
      }
    end
end
