# frozen_string_literal: true

require "aws-sdk-cognitoidentityprovider"

class Auth::CognitoAdapter
  @@provider_name = "cognito"

  class Config < Data.define(:client_id, :client_secret, :user_pool_id)
    def self.from_env
      Config.new(
        client_id: ENV["COGNITO_CLIENT_ID"],
        client_secret: ENV["COGNITO_CLIENT_SECRET"],
        user_pool_id: ENV["COGNITO_USER_POOL_ID"],
      )
    end
  end

  def initialize(client: Aws::CognitoIdentityProvider::Client.new, config: Config.from_env)
    @client = client
    @config = config
  end

  # Add a user to the Cognito user pool
  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_AdminCreateUser.html
  def create_account(email, password)
    begin
      response = @client.sign_up(
        client_id: @config.client_id,
        secret_hash: get_secret_hash(email),
        username: email,
        password: password,
        user_attributes: [
          {
            name: "email",
            value: email
          }
        ]
      )
    rescue Aws::CognitoIdentityProvider::Errors::UsernameExistsException,
      Aws::CognitoIdentityProvider::Errors::InvalidPasswordException => e
      raise to_auth_error(e)
    rescue Aws::CognitoIdentityProvider::Errors::InvalidParameterException => e
      # For some reason, Cognito raises InvalidParameterException when the password
      # is a single character, instead of InvalidPasswordException.
      raise Auth::Errors::InvalidPasswordFormat
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end

    {
      uid: response.user_sub,
      confirmation_channel: response.code_delivery_details.delivery_medium,
      provider: @@provider_name
    }
  end

  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_ForgotPassword.html
  def forgot_password(email)
    begin
      response = @client.forgot_password(
        client_id: @config.client_id,
        secret_hash: get_secret_hash(email),
        username: email
      )
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end

    {
      confirmation_channel: response.code_delivery_details.delivery_medium
    }
  end

  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_ConfirmForgotPassword.html
  def confirm_forgot_password(email, code, password)
    begin
      @client.confirm_forgot_password(
        client_id: @config.client_id,
        secret_hash: get_secret_hash(email),
        username: email,
        confirmation_code: code,
        password: password
      )
    rescue Aws::CognitoIdentityProvider::Errors::CodeMismatchException,
      Aws::CognitoIdentityProvider::Errors::ExpiredCodeException,
      Aws::CognitoIdentityProvider::Errors::InvalidPasswordException,
      Aws::CognitoIdentityProvider::Errors::UserNotConfirmedException => e
        raise to_auth_error(e)
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end
  end

  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_AdminUpdateUserAttributes.html
  def change_email(uid, new_email)
    begin
      response = @client.admin_update_user_attributes(
        user_pool_id: @config.user_pool_id,
        username: uid,
        user_attributes: [
          {
            name: "email",
            value: new_email
          },
          # Since we don't store the user's access token after they authenticate,
          # we can't use update_user_attributes, which includes an email verification
          # step (via verify_user_attribute). For now, we don't include a verification step
          # when changing email. If we want that, we need to find a way to store the user's
          # access token and keep it fresh.
          {
            name: "email_verified",
            value: "true"
          }
        ]
      )
    rescue Aws::CognitoIdentityProvider::Errors::AliasExistsException,
      Aws::CognitoIdentityProvider::Errors::UsernameExistsException => e
        raise to_auth_error(e)
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end
  end

  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_InitiateAuth.html
  def initiate_auth(email, password)
    begin
      response = @client.admin_initiate_auth(
        user_pool_id: @config.user_pool_id,
        client_id: @config.client_id,
        auth_flow: "ADMIN_USER_PASSWORD_AUTH",
        auth_parameters: {
          "USERNAME" => email,
          "PASSWORD" => password,
          "SECRET_HASH" => get_secret_hash(email)
        }
      )
    rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException,
      Aws::CognitoIdentityProvider::Errors::UserNotConfirmedException => e
        raise to_auth_error(e)
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end

    if response.challenge_name.nil?
      return get_auth_result(response)
    end

    {
      challenge_name: response.challenge_name,
      # If you must pass another challenge, this parameter should be used to compute
      # inputs to the next call (AdminRespondToAuthChallenge).
      challenge_parameters: response.challenge_parameters,
      # The session that should be passed both ways in challenge-response calls to the service.
      # If AdminInitiateAuth or AdminRespondToAuthChallenge API call determines that the caller
      # must pass another challenge, they return a session with other challenge parameters. This
      # session should be passed as it is to the next AdminRespondToAuthChallenge API call.
      session: response.session
    }
  end

  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_ResendConfirmationCode.html
  def resend_verification_code(email)
    begin
      @client.resend_confirmation_code(
        client_id: @config.client_id,
        secret_hash: get_secret_hash(email),
        username: email
      )
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end
  end

  def respond_to_auth_challenge(code, challenge = {})
    begin
      response = @client.admin_respond_to_auth_challenge(
        client_id: @config.client_id,
        user_pool_id: @config.user_pool_id,
        challenge_name: "SOFTWARE_TOKEN_MFA",
        session: challenge[:session],
        challenge_responses: {
          "SECRET_HASH" => get_secret_hash(challenge[:email]),
          "SOFTWARE_TOKEN_MFA_CODE" => code,
          "USERNAME" => challenge[:email]
        }
      )
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end

    get_auth_result(response)
  end

  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_ConfirmSignUp.html
  def verify_account(email, code)
    begin
      @client.confirm_sign_up(
        client_id: @config.client_id,
        secret_hash: get_secret_hash(email),
        username: email,
        confirmation_code: code
      )
    rescue Aws::CognitoIdentityProvider::Errors::CodeMismatchException,
      Aws::CognitoIdentityProvider::Errors::ExpiredCodeException => e
        raise to_auth_error(e)
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end
  end

  def associate_software_token(access_token)
    begin
      response = @client.associate_software_token(
        access_token: access_token
      )
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end

    response.secret_code
  end

  # https://docs.aws.amazon.com/cognito-user-identity-pools/latest/APIReference/API_VerifySoftwareToken.html
  def verify_software_token(code, access_token)
    begin
      response = @client.verify_software_token(
        access_token: access_token,
        user_code: code
      )
    rescue Aws::CognitoIdentityProvider::Errors::EnableSoftwareTokenMFAException => e
      raise to_auth_error(e)
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end

    unless response.status == "SUCCESS"
      raise Auth::Errors::InvalidSoftwareToken
    end

    begin
      @client.set_user_mfa_preference(
        access_token: access_token,
        software_token_mfa_settings: {
          enabled: true,
          preferred_mfa: true
        }
      )
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end
  end

  def disable_software_token(uid)
    begin
      @client.admin_set_user_mfa_preference(
        user_pool_id: @config.user_pool_id,
        username: uid,
        software_token_mfa_settings: {
          enabled: false,
          preferred_mfa: false
        }
      )
    rescue Aws::CognitoIdentityProvider::Errors::ServiceError => e
      raise Auth::Errors::ProviderError.new(e.message)
    end
  end

  private
    # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/CognitoIdentityProvider/Types/AuthenticationResultType.html
    def get_auth_result(response)
      {
        provider: @@provider_name,
        uid: get_sub_from_id_token(response.authentication_result.id_token),
        access_token: response.authentication_result.access_token
      }
    end

    def get_secret_hash(username)
      message = username + @config.client_id
      key = @config.client_secret
      Base64.strict_encode64(OpenSSL::HMAC.digest("sha256", key, message))
    end

    def get_sub_from_id_token(id_token)
      JWT.decode(id_token, nil, false)[0]["sub"]
    end

    # Convert an AWS Cognito SDK exception to our app's auth error equivalent
    def to_auth_error(error)
      error_map = {
        "AliasExistsException" => Auth::Errors::UsernameExists,
        "CodeMismatchException" => Auth::Errors::CodeMismatch,
        "EnableSoftwareTokenMFAException" => Auth::Errors::InvalidSoftwareToken,
        "ExpiredCodeException" => Auth::Errors::CodeExpired,
        "InvalidPasswordException" => Auth::Errors::InvalidPasswordFormat,
        "NotAuthorizedException" => Auth::Errors::InvalidCredentials,
        "UsernameExistsException" => Auth::Errors::UsernameExists,
        "UserNotConfirmedException" => Auth::Errors::UserNotConfirmed
      }

      error_map[error.class.name.demodulize] || error
    end
end
