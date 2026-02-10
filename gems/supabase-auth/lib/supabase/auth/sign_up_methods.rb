# frozen_string_literal: true

module Supabase
  module Auth
    # Sign-up methods for the Auth client.
    # Handles email/phone registration and anonymous sign-in.
    module SignUpMethods
      # Signs up a new user with email or phone and password.
      # Includes PKCE params when flow_type is :pkce.
      def sign_up(password:, **options)
        unless options[:email] || options[:phone]
          return { data: { user: nil, session: nil },
                   error: AuthInvalidCredentialsError.new("Email or phone is required") }
        end

        body = build_sign_up_body(password, options)
        append_pkce_params(body) if @flow_type == :pkce

        result = request(:post, "/signup", body: body)
        return result if result[:error]

        handle_sign_up_response(result[:data])
      end

      # Signs in anonymously (creates a new anonymous user).
      def sign_in_anonymously(**options)
        body = {}
        body[:data] = options[:data] if options[:data]
        body[:gotrue_meta_security] = { captcha_token: options[:captcha_token] } if options[:captcha_token]

        result = request(:post, "/signup", body: body)
        return result if result[:error]

        handle_session_response(result[:data])
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
          { data: { user: session.user, session: session }, error: nil }
        else
          { data: { user: data["user"] || data, session: nil }, error: nil }
        end
      end

      def handle_session_response(data)
        return { data: { user: nil, session: nil }, error: nil } unless data["access_token"]

        session = Session.new(data)
        save_session(session)
        emit_event(:signed_in, session)
        { data: { user: session.user, session: session }, error: nil }
      end

      def append_captcha(body, captcha_token)
        body[:gotrue_meta_security] = { captcha_token: captcha_token } if captcha_token
      end
    end
  end
end
