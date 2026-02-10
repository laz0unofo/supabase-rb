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

      EXPIRY_MARGIN_SECONDS = 90
      DEFAULT_LOCK_TIMEOUT = 10

      attr_reader :storage, :flow_type

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
      def get_session # rubocop:disable Naming/AccessorMethodName
        @lock.with_lock do
          session = load_session
          return { data: { session: nil }, error: nil } unless session

          return { data: { session: session }, error: nil } unless session_needs_refresh?(session)

          refresh_result = refresh_access_token(session.refresh_token)
          return refresh_result if refresh_result[:error]

          { data: { session: refresh_result[:data][:session] }, error: nil }
        end
      end

      # Returns the current user by making an HTTP call (never cached).
      def get_user(jwt: nil)
        token = jwt || current_access_token
        return { data: { user: nil }, error: AuthSessionMissingError.new("No session found") } unless token

        result = request(:get, "/user", jwt: token)
        return result if result[:error]

        { data: { user: result[:data] }, error: nil }
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
