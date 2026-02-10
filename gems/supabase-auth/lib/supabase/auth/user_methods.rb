# frozen_string_literal: true

module Supabase
  module Auth
    # User management methods for the Auth client.
    # Handles update_user, reset_password_for_email, reauthenticate, and resend.
    module UserMethods
      # Updates the current user's attributes. Emits USER_UPDATED on success.
      def update_user(**options)
        token = current_access_token
        unless token
          return { data: { user: nil },
                   error: AuthSessionMissingError.new("No session found") }
        end

        body = build_update_user_body(options)
        result = request(:put, "/user", body: body, jwt: token)
        return result if result[:error]

        session = load_session
        emit_event(:user_updated, session)
        { data: { user: result[:data] }, error: nil }
      end

      # Sends a password recovery email.
      # Includes PKCE code challenge when flow_type is :pkce,
      # and stores the verifier with /PASSWORD_RECOVERY suffix.
      def reset_password_for_email(email, redirect_to: nil, captcha_token: nil)
        body = { email: email }
        body[:redirect_to] = redirect_to if redirect_to
        body[:gotrue_meta_security] = { captcha_token: captcha_token } if captcha_token
        append_pkce_recovery_params(body) if @flow_type == :pkce

        result = request(:post, "/recover", body: body)
        return result if result[:error]

        { data: {}, error: nil }
      end

      # Sends a reauthentication request for the current user.
      def reauthenticate
        token = current_access_token
        unless token
          return { data: nil,
                   error: AuthSessionMissingError.new("No session found") }
        end

        request(:get, "/reauthenticate", jwt: token)
      end

      # Resends an OTP or confirmation to the given email/phone.
      # Includes PKCE code challenge when flow_type is :pkce.
      def resend(type:, **options)
        body = { type: type }
        body[:email] = options[:email] if options[:email]
        body[:phone] = options[:phone] if options[:phone]
        append_pkce_params(body) if @flow_type == :pkce

        result = request(:post, "/resend", body: body)
        return result if result[:error]

        { data: { message_id: result[:data]["message_id"] }, error: nil }
      end

      private

      def build_update_user_body(options)
        body = {}
        body[:email] = options[:email] if options[:email]
        body[:phone] = options[:phone] if options[:phone]
        body[:password] = options[:password] if options[:password]
        body[:nonce] = options[:nonce] if options[:nonce]
        body[:data] = options[:data] if options[:data]
        body
      end

      def append_pkce_recovery_params(body)
        verifier = PKCE.generate_code_verifier
        @storage.set_item("#{@storage_key}-code-verifier", "#{verifier}/PASSWORD_RECOVERY")
        body[:code_challenge] = PKCE.generate_code_challenge(verifier)
        body[:code_challenge_method] = PKCE.challenge_method
      end
    end
  end
end
