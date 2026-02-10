# frozen_string_literal: true

module Supabase
  module Realtime
    # Manages the heartbeat timer for keeping the WebSocket connection alive.
    module Heartbeat
      PHOENIX_TOPIC = "phoenix"
      HEARTBEAT_EVENT = "heartbeat"

      def start_heartbeat
        @pending_heartbeat_ref = nil
        stop_heartbeat

        interval_seconds = @heartbeat_interval_ms / 1000.0
        @heartbeat_thread = Thread.new do
          loop do
            sleep(interval_seconds)
            break unless @heartbeat_running

            send_heartbeat
          end
        end
        @heartbeat_running = true
      end

      def stop_heartbeat
        @heartbeat_running = false
        @heartbeat_thread&.kill
        @heartbeat_thread = nil
      end

      def send_heartbeat
        if @pending_heartbeat_ref
          log(:warn, "heartbeat timeout, attempting reconnect")
          @pending_heartbeat_ref = nil
          close_websocket
          reconnect
          return
        end

        @pending_heartbeat_ref = make_ref
        message = {
          "topic" => PHOENIX_TOPIC,
          "event" => HEARTBEAT_EVENT,
          "payload" => {},
          "ref" => @pending_heartbeat_ref
        }
        push(message)
      end

      def handle_heartbeat_reply(ref)
        @pending_heartbeat_ref = nil if @pending_heartbeat_ref == ref
      end
    end
  end
end
