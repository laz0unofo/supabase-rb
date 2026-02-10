# frozen_string_literal: true

module Supabase
  module Realtime
    # Presence registration and tracking methods for RealtimeChannel.
    module PresenceMethods
      # Registers a callback for presence events on this channel.
      #
      # @param event [Symbol] the presence event type (:sync, :join, or :leave)
      # @yield called when the specified presence event occurs
      # @return [self]
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

      # Tracks the current user's presence state on this channel.
      #
      # @param payload [Hash] the presence state to track (e.g. { online_at: Time.now })
      # @return [void]
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

      # Stops tracking the current user's presence on this channel.
      #
      # @return [void]
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
