# frozen_string_literal: true

module Supabase
  module Auth
    # Internal session management helpers for the Auth client.
    # Handles session persistence, loading, refresh checks, and event emission.
    module SessionHelpers
      private

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
          listener[:callback].call(event, session)
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
