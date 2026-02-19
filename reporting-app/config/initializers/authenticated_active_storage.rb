# frozen_string_literal: true

# Authenticate Active Storage direct uploads
#
# By default, ActiveStorage::DirectUploadsController has no authentication.
# This initializer adds authentication to prevent storage abuse.
#
# Security rationale:
# - Prevents unauthorized uploads from filling S3 bucket
# - Prevents cost attacks (unauthorized AWS charges)
# - Restricts direct uploads to admins, aligning with batch upload access control
#
# The authentication check happens BEFORE the file is uploaded to S3.

Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.class_eval do
    before_action :authenticate_user!

    private

    def authenticate_user!
      return if current_user&.admin?

      render json: { error: "Unauthorized" }, status: :unauthorized
    end

    # Current user from Warden (Devise's authentication library)
    # Warden is used by Devise to manage authentication
    def current_user
      return @current_user if defined?(@current_user)

      @current_user = warden.user if warden
    end

    # Warden authentication manager
    def warden
      request.env["warden"]
    end
  end
end
