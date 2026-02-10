# frozen_string_literal: true

module Supabase
  module Auth
    # Sign-up methods for the Auth client.
    # Handles email/phone registration and anonymous sign-in.
    module SignUpMethods
      # Signs up a new user with email or phone and password.
      # Includes PKCE params when flow_type is :pkce.
      #
      # @param password [String] the password for the new user
      # @option options [String] :email the user's email address
      # @option options [String] :phone the user's phone number
      # @option options [Hash] :data additional user metadata
      # @option options [String] :channel the messaging channel for phone sign-up (default: "sms")
      # @option options [String] :captcha_token a captcha verification token
      # @return [Hash] with :user and :session keys
      # @raise [AuthInvalidCredentialsError] when neither email nor phone provided
      # @raise [AuthApiError] on API errors
      def sign_up(password:, **options)
        raise AuthInvalidCredentialsError, "Email or phone is required" unless options[:email] || options[:phone]

        body = build_sign_up_body(password, options)
        append_pkce_params(body) if @flow_type == :pkce

        data = request(:post, "/signup", body: body)
        handle_sign_up_response(data)
      end

      # Signs in anonymously (creates a new anonymous user).
      #
      # @option options [Hash] :data additional user metadata
      # @option options [String] :captcha_token a captcha verification token
      # @return [Hash] with :user and :session keys
      # @raise [AuthApiError] on API errors
      def sign_in_anonymously(**options)
        body = {}
        body[:data] = options[:data] if options[:data]
        body[:gotrue_meta_security] = { captcha_token: options[:captcha_token] } if options[:captcha_token]

        data = request(:post, "/signup", body: body)
        handle_session_response(data)
      end

      private

      def build_sign_up_body(password, options)
        body = { password: password }
        body[:email] = options[:email] if options[:email]
        body[:phone] = options[:phone] if options[:phone]
        body[:data] = options[:data] if options[:data]
        body[:channel] = options.fetch(:channel, "sms") if options[:phone]
        append_captcha(body, options[:captcha_token])
        body
      end

      def append_pkce_params(body)
        verifier = PKCE.generate_code_verifier
        @storage.set_item("#{@storage_key}-code-verifier", verifier)
        body[:code_challenge] = PKCE.generate_code_challenge(verifier)
        body[:code_challenge_method] = PKCE.challenge_method
      end

      def handle_sign_up_response(data)
        if data["access_token"]
          session = Session.new(data)
          save_session(session)
          emit_event(:signed_in, session)
          { user: session.user, session: session }
        else
          { user: data["user"] || data, session: nil }
        end
      end

      def handle_session_response(data)
        return { user: nil, session: nil } unless data["access_token"]

        session = Session.new(data)
        save_session(session)
        emit_event(:signed_in, session)
        { user: session.user, session: session }
      end

      def append_captcha(body, captcha_token)
        body[:gotrue_meta_security] = { captcha_token: captcha_token } if captcha_token
      end
    end
  end
end
