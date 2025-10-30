# frozen_string_literal: true

# This adds a :auth_service_authenticatable accessor for use in the `devise` portion of a user model
# Heavily inspired by https://www.endpointdev.com/blog/2023/01/using-devise-for-authentication-without-database-stored-accounts/
module Devise
  module Models
    module AuthServiceAuthenticatable
      extend ActiveSupport::Concern

      module ClassMethods
        # Recreates a resource from session data.
        #
        # It takes as many params as elements in the array returned in
        # serialize_into_session.
        def serialize_from_session(id, access_token = "")
          resource = find_by(id: id)
          if resource
            resource.access_token = access_token
          end
          resource
        end

        # Returns an array with the data from the user that needs to be
        # serialized into the session.
        def serialize_into_session(user)
          [ user.id, user.access_token ]
        end
      end
    end
  end
end
