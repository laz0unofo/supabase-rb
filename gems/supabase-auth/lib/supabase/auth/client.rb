# frozen_string_literal: true

require_relative "http_handler"

module Supabase
  module Auth
    # Main Auth client for Supabase GoTrue authentication.
    # Provides the core infrastructure for session management, error handling,
    # and HTTP communication with the Auth service.
    class Client
      include HttpHandler
      include ErrorGuards

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

        request(:get, "/user", jwt: token)
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

      def load_session
        return @current_session if @current_session

        json_str = @storage.get_item(@storage_key)
        return nil unless json_str

        data = JSON.parse(json_str)
        Session.new(data)
      rescue JSON::ParserError
        nil
      end

      def save_session(session)
        @current_session = session
        @storage.set_item(@storage_key, JSON.generate(session.to_h)) if @persist_session
      end

      def remove_session
        @current_session = nil
        @storage.remove_item(@storage_key)
      end

      def session_needs_refresh?(session)
        return false unless session.expires_at

        Time.now.to_i + EXPIRY_MARGIN_SECONDS >= session.expires_at
      end

      def current_access_token
        session = @current_session || load_session
        session&.access_token
      end

      def refresh_access_token(refresh_token)
        result = request(:post, "/token?grant_type=refresh_token", body: { refresh_token: refresh_token })
        return result if result[:error]

        session = Session.new(result[:data])
        save_session(session)
        { data: { session: session }, error: nil }
      end

      def emit_event(event, session)
        @listeners.each do |listener|
          listener.call(event, session)
        rescue StandardError => e
          log_debug("Listener error: #{e.message}")
        end
      end

      def log_debug(message)
        warn "[Supabase::Auth] #{message}" if @debug
      end
    end
  end
end
