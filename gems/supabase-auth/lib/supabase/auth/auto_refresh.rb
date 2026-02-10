# frozen_string_literal: true

module Supabase
  module Auth
    # Auto-refresh methods for the Auth client.
    # Manages a background thread that periodically refreshes the session token.
    module AutoRefresh
      REFRESH_INTERVAL_SECONDS = 30
      REFRESH_TICK_THRESHOLD = 3
      BACKOFF_BASE_MS = 200
      MAX_RETRIES = 10

      # Starts the auto-refresh background thread.
      def start_auto_refresh
        return if @auto_refresh_thread&.alive?

        @auto_refresh_running = true
        @auto_refresh_thread = Thread.new { auto_refresh_loop }
      end

      # Stops the auto-refresh background thread.
      def stop_auto_refresh
        @auto_refresh_running = false
        @auto_refresh_thread&.join(1)
        @auto_refresh_thread = nil
      end

      private

      def auto_refresh_loop
        while @auto_refresh_running
          sleep(REFRESH_INTERVAL_SECONDS)
          break unless @auto_refresh_running

          attempt_auto_refresh
        end
      rescue StandardError => e
        log_debug("Auto-refresh loop error: #{e.message}")
      end

      def attempt_auto_refresh
        session = load_session
        return unless session

        return unless should_auto_refresh?(session)

        auto_refresh_with_retry(session.refresh_token)
      end

      def should_auto_refresh?(session)
        return false unless session.expires_at

        ticks_remaining = (session.expires_at - Time.now.to_i) / REFRESH_INTERVAL_SECONDS
        ticks_remaining <= REFRESH_TICK_THRESHOLD
      end

      def auto_refresh_with_retry(refresh_token)
        retries = 0
        loop do
          result = refresh_access_token(refresh_token)
          unless result[:error]
            emit_event(:token_refreshed, result[:data][:session])
            return
          end

          break unless result[:error].is_a?(AuthRetryableFetchError)

          retries += 1
          break if retries >= MAX_RETRIES

          backoff_ms = BACKOFF_BASE_MS * (2**(retries - 1))
          sleep(backoff_ms / 1000.0)
        end
      end
    end
  end
end
