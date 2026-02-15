# Identity provider configuration.
# If the notification service is configured, the identity provider will use the
# SES-verified email to send notifications.
locals {
  # If your application should redirect users, after successful authentication, to a
  # page other than the homepage, specify the path fragment here.
  # Example: "profile"
  # Docs: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-client-apps.html
  callback_url_path = ""

  # If your application should redirect users, after signing out, to a page other than
  # the homepage, specify the path fragment here.
  # Example: "logout"
  # Docs: https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-settings-client-apps.html
  logout_url_path = ""

  # Customize password policy
  # Docs: https://docs.aws.amazon.com/cognito/latest/developerguide/managing-users-passwords.html
  password_policy = {
    password_minimum_length          = 12
    temporary_password_validity_days = 7
  }

  # Optionally configure email template for resetting a password.
  # Set any attribute to a non-null value to override AWS Cognito defaults.
  # Docs: https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pool-settings-message-customizations.html
  verification_email = {
    verification_email_message = null
    verification_email_subject = null
  }

  # SSO callback path for Staff Single Sign-On via OIDC
  sso_callback_url_path = "auth/sso/callback"

  identity_provider_config = var.enable_identity_provider ? {
    identity_provider_name = "${var.app_name}-${var.environment}"

    password_policy = local.password_policy

    verification_email = local.verification_email

    # Staff SSO enabled flag (for service layer to conditionally add SSO env vars)
    enable_sso = var.enable_sso

    # Client configuration for Cognito app client
    # When SSO is enabled, includes the /auth/sso/callback URL
    #
    # Do not hardcode URLs here. Instead use:
    #   - callback_url_path / logout_url_path locals for main app paths
    #   - sso_callback_url_path local for SSO callback path
    #   - extra_identity_provider_callback_urls variable for additional URLs (e.g., ngrok)
    client = {
      callback_urls = concat(
        var.domain_name != null ? ["https://${var.domain_name}/${local.callback_url_path}"] : [],
        # Add SSO callback URL when SSO is enabled
        var.enable_sso && var.domain_name != null ? ["https://${var.domain_name}/${local.sso_callback_url_path}"] : [],
        var.extra_identity_provider_callback_urls,
        var.sso_callback_urls
      )
      logout_urls = concat(
        var.domain_name != null ? ["https://${var.domain_name}/${local.logout_url_path}"] : [],
        var.extra_identity_provider_logout_urls,
        var.sso_logout_urls
      )
    }
  } : null
}
