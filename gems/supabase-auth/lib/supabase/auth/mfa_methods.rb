# frozen_string_literal: true

module Supabase
  module Auth
    # MFA integration methods for the Auth client.
    # Provides the mfa accessor and internal helpers for MFA operations.
    module MfaMethods
      # Returns the MFA API object for multi-factor authentication operations.
      def mfa
        @mfa ||= MfaApi.new(self)
      end

      private

      # Makes an authenticated MFA request.
      def mfa_request(method, path, body: nil)
        token = current_access_token
        unless token
          return { data: nil,
                   error: AuthSessionMissingError.new("No session found") }
        end

        request(method, path, body: body, jwt: token)
      end

      # Handles a successful MFA verify response by saving session and emitting event.
      def handle_mfa_verify(data)
        session = Session.new(data)
        save_session(session)
        emit_event(:mfa_challenge_verified, session)
        { data: data, error: nil }
      end
    end
  end
end
