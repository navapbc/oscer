# frozen_string_literal: true

# API endpoint for presigned S3 upload URLs.
#
# Inherits ActiveStorage::DirectUploadsController (which inherits ActionController::Base,
# not ActionController::Metal like ApiController) so we can't use ApiController as a base.
# HMAC auth is shared via the ApiHmacAuthentication concern.
#
# The monkey-patch in config/initializers/authenticated_active_storage.rb adds
# Devise's `authenticate_user!` to the parent class. We must skip it so HMAC
# auth can run instead — without this, all API requests fail 401 before HMAC runs.
class Api::DirectUploadsController < ActiveStorage::DirectUploadsController
  include ApiHmacAuthentication

  skip_before_action :authenticate_user!
  protect_from_forgery with: :null_session

  before_action :authenticate_api_request!
end
