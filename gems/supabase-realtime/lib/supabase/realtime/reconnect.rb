# frozen_string_literal: true

module Supabase
  module Realtime
    # Manages reconnection with exponential backoff.
    module Reconnect
      DEFAULT_BACKOFF_MS = [1_000, 2_000, 5_000, 10_000].freeze

      def reconnect
        return if @state == :connecting

        @reconnect_attempt ||= 0
        delay_ms = reconnect_delay_ms(@reconnect_attempt)
        @reconnect_attempt += 1

        log(:info, "reconnecting in #{delay_ms}ms (attempt #{@reconnect_attempt})")

        @reconnect_thread = Thread.new do
          sleep(delay_ms / 1000.0)
          do_connect
        end
      end

      def reset_reconnect
        @reconnect_attempt = 0
        @reconnect_thread&.kill
        @reconnect_thread = nil
      end

      private

      def reconnect_delay_ms(attempt)
        if @reconnect_after_ms
          @reconnect_after_ms.call(attempt)
        else
          DEFAULT_BACKOFF_MS[attempt] || DEFAULT_BACKOFF_MS.last
        end
      end
    end
  end
end
