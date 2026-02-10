# frozen_string_literal: true

module Supabase
  module Auth
    # Verification methods for the Auth client.
    # Handles OTP verification and PKCE code exchange.
    module VerifyMethods
      # Verifies an OTP token. Saves session on success.
      #
      # @option options [String] :type the verification type (e.g. "sms", "email", "recovery", "invite")
      # @option options [String] :email the user's email address
      # @option options [String] :phone the user's phone number
      # @option options [String] :token_hash the hashed OTP token
      # @option options [String] :token the plain OTP token
      # @option options [String] :captcha_token a captcha verification token
      # @return [Hash] with :user and :session keys
      # @raise [AuthApiError] on API errors
      def verify_otp(**options)
        body = build_verify_body(options)
        data = request(:post, "/verify", body: body)
        handle_session_response(data)
      end

      # Exchanges a PKCE auth code for a session.
      #
      # @param auth_code [String] the authorization code received from the OAuth callback
      # @return [Hash] with :user and :session keys
      # @raise [AuthPKCEGrantCodeExchangeError] when no code verifier is found
      def exchange_code_for_session(auth_code)
        verifier = @storage.get_item("#{@storage_key}-code-verifier")
        raise AuthPKCEGrantCodeExchangeError, "No code verifier found in storage" unless verifier

        clean_verifier = verifier.sub(%r{/PASSWORD_RECOVERY\z}, "")
        @storage.remove_item("#{@storage_key}-code-verifier")

        data = request(:post, "/token?grant_type=pkce",
                       body: { auth_code: auth_code, code_verifier: clean_verifier })
        handle_exchange_response(data, verifier)
      end

      private

      def build_verify_body(options)
        body = { type: options[:type] }
        body[:email] = options[:email] if options[:email]
        body[:phone] = options[:phone] if options[:phone]
        body[:token_hash] = options[:token_hash] if options[:token_hash]
        body[:token] = options[:token] if options[:token]
        append_captcha(body, options[:captcha_token])
        body
      end

      def handle_exchange_response(data, verifier)
        session = Session.new(data)
        save_session(session)

        if verifier.end_with?("/PASSWORD_RECOVERY")
          emit_event(:password_recovery, session)
        else
          emit_event(:signed_in, session)
        end

        { user: session.user, session: session }
      end
    end
  end
end
