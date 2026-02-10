# frozen_string_literal: true

module Supabase
  module Auth
    # Admin integration methods for the Auth client.
    # Provides the admin accessor and internal helpers for admin operations.
    module AdminMethods
      # Returns the Admin API object for user management operations.
      def admin
        @admin ||= AdminApi.new(self)
      end

      private

      # Makes an admin request using the service role key from client headers.
      # Admin requests use the apikey header as the authorization token
      # unless a specific JWT is provided.
      def admin_request(method, path, body: nil, jwt: nil)
        token = jwt || @headers["apikey"] || @headers["Authorization"]&.sub("Bearer ", "")
        request(method, path, body: body, jwt: token)
      end
    end
  end
end
