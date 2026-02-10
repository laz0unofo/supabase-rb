# frozen_string_literal: true

module Supabase
  module Auth
    # User management methods for the Auth client.
    # Handles update_user, reset_password_for_email, reauthenticate, and resend.
    module UserMethods
      # Updates the current user's attributes. Emits USER_UPDATED on success.
      #
      # @option options [String] :email the new email address
      # @option options [String] :phone the new phone number
      # @option options [String] :password the new password
      # @option options [String] :nonce a nonce for reauthentication when changing password
      # @option options [Hash] :data additional user metadata to update
      # @return [Hash] with :user key
      # @raise [AuthSessionMissingError] when no session exists
      def update_user(**options)
        token = current_access_token
        raise AuthSessionMissingError, "No session found" unless token

        body = build_update_user_body(options)
        data = request(:put, "/user", body: body, jwt: token)

        session = load_session
        emit_event(:user_updated, session)
        { user: data }
      end

      # Sends a password recovery email.
      # Includes PKCE code challenge when flow_type is :pkce,
      # and stores the verifier with /PASSWORD_RECOVERY suffix.
      #
      # @param email [String] the email address to send the recovery link to
      # @param redirect_to [String, nil] the URL to redirect to after password reset
      # @param captcha_token [String, nil] a captcha verification token
      # @return [Hash] empty hash on success
      # @raise [AuthApiError] on API errors
      def reset_password_for_email(email, redirect_to: nil, captcha_token: nil)
        body = { email: email }
        body[:redirect_to] = redirect_to if redirect_to
        body[:gotrue_meta_security] = { captcha_token: captcha_token } if captcha_token
        append_pkce_recovery_params(body) if @flow_type == :pkce

        request(:post, "/recover", body: body)
        {}
      end

      # Sends a reauthentication request for the current user.
      #
      # @return [Object] parsed response data
      # @raise [AuthSessionMissingError] when no session exists
      def reauthenticate
        token = current_access_token
        raise AuthSessionMissingError, "No session found" unless token

        request(:get, "/reauthenticate", jwt: token)
      end

      # Resends an OTP or confirmation to the given email/phone.
      # Includes PKCE code challenge when flow_type is :pkce.
      #
      # @param type [String] the resend type (e.g. "signup", "sms", "email_change")
      # @option options [String] :email the user's email address
      # @option options [String] :phone the user's phone number
      # @return [Hash] with :message_id key
      # @raise [AuthApiError] on API errors
      def resend(type:, **options)
        body = { type: type }
        body[:email] = options[:email] if options[:email]
        body[:phone] = options[:phone] if options[:phone]
        append_pkce_params(body) if @flow_type == :pkce

        data = request(:post, "/resend", body: body)
        { message_id: data["message_id"] }
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
