# frozen_string_literal: true

require "uri"

module Supabase
  module Auth
    # Sign-in methods for the Auth client.
    # Handles password, OAuth, OTP, ID token, and SSO authentication.
    module SignInMethods
      # Signs in with email/phone and password.
      def sign_in_with_password(password:, **options)
        body = build_password_body(password, options)

        result = request(:post, "/token?grant_type=password", body: body)
        return result if result[:error]

        handle_session_response(result[:data])
      end

      # Builds an OAuth authorize URL (no HTTP call).
      def sign_in_with_oauth(**options)
        params = build_oauth_base_params(options)
        append_oauth_pkce(params)
        url = "#{@url}/authorize?#{URI.encode_www_form(params)}"
        { data: { provider: options[:provider], url: url }, error: nil }
      end

      # Signs in with OTP (one-time password) via email or phone.
      def sign_in_with_otp(**options)
        body = build_otp_body(options)
        append_pkce_params(body) if @flow_type == :pkce

        result = request(:post, "/otp", body: body)
        return result if result[:error]

        { data: { message_id: result[:data]["message_id"] }, error: nil }
      end

      # Signs in with an ID token from an external provider.
      def sign_in_with_id_token(**options)
        body = build_id_token_body(options)

        result = request(:post, "/token?grant_type=id_token", body: body)
        return result if result[:error]

        handle_session_response(result[:data])
      end

      # Signs in with SSO (Single Sign-On) via provider_id or domain.
      def sign_in_with_sso(**options)
        body = build_sso_body(options)
        append_pkce_params(body) if @flow_type == :pkce

        result = request(:post, "/sso", body: body)
        return result if result[:error]

        { data: { url: result[:data]["url"] }, error: nil }
      end

      private

      def build_password_body(password, options)
        body = { password: password }
        body[:email] = options[:email] if options[:email]
        body[:phone] = options[:phone] if options[:phone]
        append_captcha(body, options[:captcha_token])
        body
      end

      def build_oauth_base_params(options)
        params = { provider: options[:provider] }
        params[:redirect_to] = options[:redirect_to] if options[:redirect_to]
        params[:scopes] = options[:scopes] if options[:scopes]
        params[:skip_browser_redirect] = options[:skip_browser_redirect] unless options[:skip_browser_redirect].nil?
        (options[:query_params] || {}).each { |key, val| params[key] = val }
        params
      end

      def append_oauth_pkce(params)
        return unless @flow_type == :pkce

        verifier = PKCE.generate_code_verifier
        @storage.set_item("#{@storage_key}-code-verifier", verifier)
        params[:code_challenge] = PKCE.generate_code_challenge(verifier)
        params[:code_challenge_method] = PKCE.challenge_method
      end

      def build_otp_body(options)
        body = { create_user: options.fetch(:should_create_user, true) }
        body[:email] = options[:email] if options[:email]
        body[:phone] = options[:phone] if options[:phone]
        body[:data] = options[:data] if options[:data]
        body[:channel] = options.fetch(:channel, "sms") if options[:phone]
        append_captcha(body, options[:captcha_token])
        body
      end

      def build_id_token_body(options)
        body = { provider: options[:provider], token: options[:token] }
        body[:access_token] = options[:access_token] if options[:access_token]
        body[:nonce] = options[:nonce] if options[:nonce]
        append_captcha(body, options[:captcha_token])
        body
      end

      def build_sso_body(options)
        body = {}
        body[:provider_id] = options[:provider_id] if options[:provider_id]
        body[:domain] = options[:domain] if options[:domain]
        body[:redirect_to] = options[:redirect_to] if options[:redirect_to]
        append_captcha(body, options[:captcha_token])
        body
      end
    end
  end
end
