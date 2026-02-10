# frozen_string_literal: true

require "uri"

module Supabase
  module Auth
    # Sign-in methods for the Auth client.
    # Handles password, OAuth, OTP, ID token, and SSO authentication.
    module SignInMethods
      # Signs in with email/phone and password.
      #
      # @param password [String] the user's password
      # @option options [String] :email the user's email address
      # @option options [String] :phone the user's phone number
      # @option options [String] :captcha_token a captcha verification token
      # @return [Hash] session data with :user and :session keys
      # @raise [AuthApiError] on API errors
      # @raise [AuthRetryableFetchError] on network failures
      def sign_in_with_password(password:, **options)
        body = build_password_body(password, options)
        data = request(:post, "/token?grant_type=password", body: body)
        handle_session_response(data)
      end

      # Builds an OAuth authorize URL (no HTTP call).
      #
      # @option options [String] :provider the OAuth provider name (e.g. "google", "github")
      # @option options [String] :redirect_to the URL to redirect to after authorization
      # @option options [String] :scopes OAuth scopes to request
      # @option options [Boolean] :skip_browser_redirect whether to skip automatic browser redirect
      # @option options [Hash] :query_params additional query parameters to include in the URL
      # @return [Hash] with :provider and :url keys
      def sign_in_with_oauth(**options)
        params = build_oauth_base_params(options)
        append_oauth_pkce(params)
        url = "#{@url}/authorize?#{URI.encode_www_form(params)}"
        { provider: options[:provider], url: url }
      end

      # Signs in with OTP (one-time password) via email or phone.
      #
      # @option options [String] :email the user's email address
      # @option options [String] :phone the user's phone number
      # @option options [Boolean] :should_create_user whether to create the user if they don't exist (default: true)
      # @option options [Hash] :data additional user metadata
      # @option options [String] :channel the messaging channel for phone OTP (default: "sms")
      # @option options [String] :captcha_token a captcha verification token
      # @return [Hash] with :message_id key
      # @raise [AuthApiError] on API errors
      def sign_in_with_otp(**options)
        body = build_otp_body(options)
        append_pkce_params(body) if @flow_type == :pkce

        data = request(:post, "/otp", body: body)
        { message_id: data["message_id"] }
      end

      # Signs in with an ID token from an external provider.
      #
      # @option options [String] :provider the external identity provider (e.g. "google", "apple")
      # @option options [String] :token the ID token issued by the provider
      # @option options [String] :access_token an optional provider access token
      # @option options [String] :nonce an optional nonce for token verification
      # @option options [String] :captcha_token a captcha verification token
      # @return [Hash] session data with :user and :session keys
      # @raise [AuthApiError] on API errors
      def sign_in_with_id_token(**options)
        body = build_id_token_body(options)
        data = request(:post, "/token?grant_type=id_token", body: body)
        handle_session_response(data)
      end

      # Signs in with SSO (Single Sign-On) via provider_id or domain.
      #
      # @option options [String] :provider_id the SSO provider identifier
      # @option options [String] :domain the SSO domain to authenticate with
      # @option options [String] :redirect_to the URL to redirect to after authentication
      # @option options [String] :captcha_token a captcha verification token
      # @return [Hash] with :url key
      # @raise [AuthApiError] on API errors
      def sign_in_with_sso(**options)
        body = build_sso_body(options)
        append_pkce_params(body) if @flow_type == :pkce

        data = request(:post, "/sso", body: body)
        { url: data["url"] }
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
