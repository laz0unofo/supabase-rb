# frozen_string_literal: true

module Supabase
  module Realtime
    # Presence registration and tracking methods for RealtimeChannel.
    module PresenceMethods
      def on_presence(event, &)
        case event
        when :sync
          @presence.on_sync(&)
        when :join
          @presence.on_join(&)
        when :leave
          @presence.on_leave(&)
        end
        self
      end

      def track(payload)
        message = {
          "topic" => @topic,
          "event" => "presence",
          "payload" => {
            "event" => "track",
            "payload" => payload,
            "type" => "presence"
          },
          "ref" => @client.make_ref,
          "join_ref" => @join_ref
        }
        @client.push(message)
      end

      def untrack
        message = {
          "topic" => @topic,
          "event" => "presence",
          "payload" => {
            "event" => "untrack",
            "type" => "presence"
          },
          "ref" => @client.make_ref,
          "join_ref" => @join_ref
        }
        @client.push(message)
      end
    end
  end
end
