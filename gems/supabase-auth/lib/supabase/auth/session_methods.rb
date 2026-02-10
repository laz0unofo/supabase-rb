# frozen_string_literal: true

module Supabase
  module Auth
    # Session management methods for the Auth client.
    # Handles set_session, refresh_session, and sign_out.
    module SessionMethods
      # Sets a session from access_token and refresh_token.
      # Decodes JWT, validates structure, refreshes if expired, saves and emits events.
      #
      # @param access_token [String] a valid JWT access token
      # @param refresh_token [String] the refresh token for obtaining new access tokens
      # @return [Hash{Symbol => Hash, nil}] result with data and error keys
      def set_session(access_token:, refresh_token:)
        @lock.with_lock do
          payload = JWT.decode(access_token)
          unless payload
            return { data: { user: nil, session: nil },
                     error: AuthInvalidTokenResponseError.new("Invalid access token") }
          end

          return refresh_and_save(refresh_token, :token_refreshed) if token_expired?(payload)

          build_and_save_session(access_token, refresh_token, payload)
        end
      end

      # Refreshes the current session using the provided or stored refresh token.
      #
      # @param current_session [Session, nil] optional session whose
      #   refresh token to use; falls back to stored session
      # @return [Hash{Symbol => Hash, nil}] result with data and error keys
      def refresh_session(current_session: nil)
        @lock.with_lock do
          token = current_session&.refresh_token
          token ||= load_session&.refresh_token
          unless token
            return { data: { user: nil, session: nil },
                     error: AuthSessionMissingError.new("No current session") }
          end

          refresh_and_save(token, :token_refreshed)
        end
      end

      # Signs the user out and removes the local session.
      # Scope: :global (all sessions), :local (only local), :others (all except current).
      #
      # @param scope [Symbol] the sign-out scope -- :global, :local, or :others
      # @return [Hash{Symbol => nil, AuthError}] { error: nil | AuthError }
      def sign_out(scope: :global)
        token = current_access_token
        remove_session
        stop_auto_refresh
        emit_event(:signed_out, nil)

        return { error: nil } if scope == :local || token.nil?

        result = request(:post, "/logout", jwt: token, body: { scope: scope.to_s })
        return { error: result[:error] } if result[:error]

        { error: nil }
      end

      private

      def token_expired?(payload)
        payload["exp"] && payload["exp"] <= Time.now.to_i
      end

      def build_and_save_session(access_token, refresh_token, payload)
        data = {
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "expires_at" => payload["exp"],
          "token_type" => "bearer",
          "user" => payload
        }
        session = Session.new(data)
        save_session(session)
        emit_event(:signed_in, session)
        emit_event(:token_refreshed, session)
        { data: { user: session.user, session: session }, error: nil }
      end

      def refresh_and_save(refresh_token, event)
        result = refresh_access_token(refresh_token)
        return result if result[:error]

        session = result[:data][:session]
        emit_event(event, session)
        { data: { user: session.user, session: session }, error: nil }
      end
    end
  end
end
