# frozen_string_literal: true

module Supabase
  module Realtime
    # Handles incoming messages for a RealtimeChannel.
    module ChannelMessageHandler
      WILDCARD = "*"
      SYSTEM_EVENTS = %w[phx_reply phx_close phx_error].freeze
      REALTIME_EVENTS = %w[broadcast presence_diff presence_state postgres_changes].freeze

      def handle_message(message)
        event = message["event"]
        payload = message["payload"]
        ref = message["ref"]

        return handle_system_event(event, payload, ref) if SYSTEM_EVENTS.include?(event)

        handle_realtime_event(event, payload)
      end

      private

      def handle_system_event(event, payload, ref)
        case event
        when "phx_reply" then handle_reply(payload, ref)
        when "phx_close" then @state = :closed
        when "phx_error" then handle_error(payload)
        end
      end

      def handle_realtime_event(event, payload)
        case event
        when "broadcast" then dispatch_broadcast(payload)
        when "presence_diff" then dispatch_presence_diff(payload)
        when "presence_state" then dispatch_presence_state(payload)
        when "postgres_changes" then dispatch_postgres_changes(payload)
        else dispatch_event(event, payload)
        end
      end

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

      def dispatch_broadcast(payload)
        event = payload["event"]
        @bindings.each do |binding|
          next unless binding[:type] == :broadcast
          next unless [event, WILDCARD].include?(binding[:event])

          binding[:callback]&.call(payload["payload"])
        end
      end

      def dispatch_presence_diff(payload)
        joins = payload["joins"] || {}
        leaves = payload["leaves"] || {}
        @presence.sync_diff(joins, leaves)
      end

      def dispatch_presence_state(payload)
        joins = payload.dup
        joins.delete("type") if joins.is_a?(Hash)
        @presence.sync(joins, joins, {})
      end

      def dispatch_postgres_changes(payload)
        pg_data = payload["data"] || payload
        pg_event = pg_data["type"]

        @bindings.each do |binding|
          next unless binding[:type] == :postgres_changes
          next unless matches_pg_binding?(binding, pg_data, pg_event)

          binding[:callback]&.call(pg_data)
        end
      end

      def matches_pg_binding?(binding, pg_data, pg_event)
        return false unless [WILDCARD, pg_event].include?(binding[:event])

        matches_pg_schema_and_table?(binding, pg_data)
      end

      def matches_pg_schema_and_table?(binding, pg_data)
        return false if binding[:schema] != pg_data["schema"]
        return true unless binding[:table]

        binding[:table] == pg_data["table"]
      end

      def dispatch_event(event, payload)
        @bindings.each do |binding|
          next unless [event, WILDCARD].include?(binding[:event])

          binding[:callback]&.call(payload)
        end
      end
    end
  end
end
