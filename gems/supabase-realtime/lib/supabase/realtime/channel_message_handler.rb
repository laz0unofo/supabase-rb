# frozen_string_literal: true

module Supabase
  module Realtime
    # Handles incoming messages for a RealtimeChannel.
    module ChannelMessageHandler
      WILDCARD_EVENT = "*"

      def handle_message(message)
        event = message["event"]
        payload = message["payload"]
        ref = message["ref"]

        case event
        when "phx_reply"
          handle_reply(payload, ref)
        when "phx_close"
          @state = :closed
        when "phx_error"
          handle_error(payload)
        else
          dispatch_event(event, payload)
        end
      end

      private

      def handle_reply(payload, ref)
        status = payload["status"]
        handle_join_reply(status, payload) if ref == @join_ref
      end

      def handle_join_reply(status, payload)
        if status == "ok"
          @state = :joined
          @subscribe_callback&.call(:subscribed, nil)
        else
          @state = :closed
          error = RealtimeSubscriptionError.new(
            payload.dig("response", "message") || "join failed"
          )
          @subscribe_callback&.call(:channel_error, error)
        end
      end

      def handle_error(payload)
        @state = :closed
        error = RealtimeSubscriptionError.new(
          payload["message"] || "channel error"
        )
        @subscribe_callback&.call(:channel_error, error)
      end

      def dispatch_event(event, payload)
        @bindings.each do |binding|
          next unless [event, WILDCARD_EVENT].include?(binding[:event])

          binding[:callback]&.call(payload)
        end
      end
    end
  end
end
