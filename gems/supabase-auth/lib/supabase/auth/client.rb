# frozen_string_literal: true

require_relative "http_handler"
require_relative "session_helpers"
require_relative "sign_up_methods"
require_relative "sign_in_methods"
require_relative "verify_methods"
require_relative "session_methods"
require_relative "auto_refresh"
require_relative "user_methods"
require_relative "auth_state_events"
require_relative "mfa_api"
require_relative "mfa_methods"
require_relative "admin_api"
require_relative "admin_methods"

module Supabase
  module Auth
    # Main Auth client for Supabase GoTrue authentication.
    # Provides the core infrastructure for session management, error handling,
    # and HTTP communication with the Auth service.
    class Client
      include HttpHandler
      include ErrorGuards
      include SessionHelpers
      include SignUpMethods
      include SignInMethods
      include VerifyMethods
      include SessionMethods
      include AutoRefresh
      include UserMethods
      include AuthStateEvents
      include MfaMethods
      include AdminMethods

      DEFAULT_LOCK_TIMEOUT = 10

      attr_reader :storage, :flow_type

      # Initializes a new Auth client for communicating with the Supabase GoTrue service.
      #
      # @param url [String] the base URL of the GoTrue auth server
      # @param headers [Hash] additional HTTP headers to include in every request
      # @option options [String] :storage_key the key for persisting session
      #   in storage (default: "supabase.auth.token")
      # @option options [Boolean] :auto_refresh_token whether to auto-refresh expiring tokens (default: true)
      # @option options [Boolean] :persist_session whether to persist the session to storage (default: true)
      # @option options [Boolean] :detect_session_in_url whether to detect session info in URL (default: true)
      # @option options [Symbol] :flow_type the auth flow type, :implicit or :pkce (default: :implicit)
      # @option options [Object] :lock a custom lock instance for thread-safety
      # @option options [Object] :storage a custom storage backend (default: MemoryStorage)
      # @option options [Object] :fetch a custom fetch/HTTP handler
      # @option options [Boolean] :debug enable debug logging (default: false)
      def initialize(url:, headers: {}, **options)
        @url = url.to_s.chomp("/")
        @headers = headers.dup
        configure_options(options)
        @lock = options[:lock] || Lock.new(timeout: DEFAULT_LOCK_TIMEOUT)
        @storage = resolve_storage(options[:storage])
        @fetch = options[:fetch]
        @debug = options[:debug] || false
        @listeners = []
        @current_session = nil
        @auto_refresh_running = false
        @auto_refresh_thread = nil
      end

      # Returns the currently stored session, refreshing if expired.
      #
      # @return [Hash] with :session key (Session or nil)
      def get_session # rubocop:disable Naming/AccessorMethodName
        @lock.with_lock do
          session = load_session
          return { session: nil } unless session

          return { session: session } unless session_needs_refresh?(session)

          refreshed = refresh_access_token(session.refresh_token)
          { session: refreshed }
        end
      end

      # Returns the current user by making an HTTP call (never cached).
      #
      # @param jwt [String, nil] an optional JWT to use instead of the stored access token
      # @return [Hash] with :user key
      # @raise [AuthSessionMissingError] when no session exists and no JWT provided
      def get_user(jwt: nil)
        token = jwt || current_access_token
        raise AuthSessionMissingError, "No session found" unless token

        data = request(:get, "/user", jwt: token)
        { user: data }
      end

      private

      def configure_options(options)
        @storage_key = options[:storage_key] || "supabase.auth.token"
        @auto_refresh_token = options.fetch(:auto_refresh_token, true)
        @persist_session = options.fetch(:persist_session, true)
        @detect_session_in_url = options.fetch(:detect_session_in_url, true)
        @flow_type = options.fetch(:flow_type, :implicit)
      end

      def resolve_storage(storage)
        return storage if storage

        MemoryStorage.new
      end
    end
  end
end
