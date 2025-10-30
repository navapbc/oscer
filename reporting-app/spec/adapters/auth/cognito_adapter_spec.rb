# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::CognitoAdapter do
  let(:mock_client) { instance_double(Aws::CognitoIdentityProvider::Client) }
  let(:dummy_config) { Auth::CognitoAdapter::Config.new(client_id: "Foo", client_secret: "Bar", user_pool_id: "Baz") }
  let(:adapter) { described_class.new(client: mock_client, config: dummy_config) }
  let(:email) { "test@example.com" }

  describe "#associate_software_token" do
    it "returns the secret_code" do
      secret_code = "123456abcdef"
      allow(mock_client).to receive(:associate_software_token).and_return(
        Aws::CognitoIdentityProvider::Types::AssociateSoftwareTokenResponse.new(
          secret_code: secret_code
        )
      )

      response = adapter.associate_software_token("access_token")

      expect(response).to eq(secret_code)
    end

    it "raises a provider error if cognito raises an unhandled service error" do
      allow(mock_client).to receive(:associate_software_token).and_raise(
        Aws::CognitoIdentityProvider::Errors::TooManyRequestsException.new(nil, "mock msg")
      )

      expect do
        adapter.associate_software_token("access_token")
      end.to raise_error(Auth::Errors::ProviderError)
    end
  end

  describe "#create_account" do
    it "raises an error if the email is already taken" do
      allow(mock_client).to receive(:sign_up).and_raise(Aws::CognitoIdentityProvider::Errors::UsernameExistsException.new(nil, "mock msg"))

      expect do
        adapter.create_account(email, "password")
      end.to raise_error(Auth::Errors::UsernameExists)
    end

    it "raises an error if the password is invalid" do
      allow(mock_client).to receive(:sign_up).and_raise(Aws::CognitoIdentityProvider::Errors::InvalidPasswordException.new(nil, "mock msg"))

      expect do
        adapter.create_account(email, "password")
      end.to raise_error(Auth::Errors::InvalidPasswordFormat)
    end

    it "raises an invalid password error if cognito raises an invalid parameter exception" do
      allow(mock_client).to receive(:sign_up).and_raise(Aws::CognitoIdentityProvider::Errors::InvalidParameterException.new(nil, "mock msg"))

      expect do
        adapter.create_account(email, "a")
      end.to raise_error(Auth::Errors::InvalidPasswordFormat)
    end

    it "raises a provider error if cognito raises an unhandled service error" do
      allow(mock_client).to receive(:sign_up).and_raise(Aws::CognitoIdentityProvider::Errors::TooManyRequestsException.new(nil, "mock msg"))

      expect do
        adapter.create_account(email, "password")
      end.to raise_error(Auth::Errors::ProviderError)
    end
  end

  describe "#initiate_auth" do
    it "raises an error if the password is incorrect" do
      allow(mock_client).to receive(:admin_initiate_auth).and_raise(Aws::CognitoIdentityProvider::Errors::NotAuthorizedException.new(nil, "mock msg"))

      expect do
        adapter.initiate_auth(email, "password")
      end.to raise_error(Auth::Errors::InvalidCredentials)
    end

    it "raises a provider error if cognito raises an unhandled service error" do
      allow(mock_client).to receive(:admin_initiate_auth).and_raise(Aws::CognitoIdentityProvider::Errors::TooManyRequestsException.new(nil, "mock msg"))

      expect do
        adapter.initiate_auth(email, "password")
      end.to raise_error(Auth::Errors::ProviderError)
    end
  end

  describe "#forgot_password" do
    it "responds with the confirmation channel" do
      allow(mock_client).to receive(:forgot_password).and_return(
        Aws::CognitoIdentityProvider::Types::ForgotPasswordResponse.new(
          code_delivery_details: Aws::CognitoIdentityProvider::Types::CodeDeliveryDetailsType.new(delivery_medium: "EMAIL")
        )
      )
      response = adapter.forgot_password(email)

      expect(response).to eq({ confirmation_channel: "EMAIL" })
    end
  end

  describe "#verify_software_token" do
    it "sets the MFA preference when the token is verified" do
      allow(mock_client).to receive_messages(verify_software_token: Aws::CognitoIdentityProvider::Types::VerifySoftwareTokenResponse.new(
          status: "SUCCESS"
        ), set_user_mfa_preference: Aws::CognitoIdentityProvider::Types::SetUserMFAPreferenceResponse.new)

      adapter.verify_software_token("123456", "mock_token")

      expect(mock_client).to have_received(:set_user_mfa_preference).with(
        access_token: "mock_token",
        software_token_mfa_settings: {
          enabled: true,
          preferred_mfa: true
        }
      )
    end

    it "raises an error if the response status isn't success" do
      allow(mock_client).to receive(:verify_software_token).and_return(
        Aws::CognitoIdentityProvider::Types::VerifySoftwareTokenResponse.new(
          status: "FAILED"
        )
      )

      expect do
        adapter.verify_software_token("123456", "mock_token")
      end.to raise_error(Auth::Errors::InvalidSoftwareToken)
    end


    it "raises an error when EnableSoftwareTokenMFAException is raised" do
      allow(mock_client).to receive(:verify_software_token).and_raise(
        Aws::CognitoIdentityProvider::Errors::EnableSoftwareTokenMFAException.new(nil, "mock msg")
      )

      expect do
        adapter.verify_software_token("123456", "mock_token")
      end.to raise_error(Auth::Errors::InvalidSoftwareToken)
    end

    it "raises a provider error when cognito raises an unhandled service error" do
      allow(mock_client).to receive(:verify_software_token).and_raise(
        Aws::CognitoIdentityProvider::Errors::TooManyRequestsException.new(nil, "mock msg")
      )

      expect do
        adapter.verify_software_token("123456", "mock_token")
      end.to raise_error(Auth::Errors::ProviderError)
    end
  end
end
