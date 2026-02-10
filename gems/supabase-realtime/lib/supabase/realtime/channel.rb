# frozen_string_literal: true

module Supabase
  module Realtime
    # Represents a channel subscription on the Realtime server.
    # Supports broadcast, presence, and postgres_changes listeners.
    class RealtimeChannel
      include ChannelMessageHandler
      include BroadcastMethods
      include PresenceMethods
      include PostgresChangesMethods

      STATES = %i[closed joining joined leaving].freeze

      attr_reader :topic, :client, :state, :join_ref, :presence

      # Creates a new channel for the given topic.
      #
      # @param topic [String] the channel topic (e.g. "realtime:my-room")
      # @param client [Client] the parent Realtime client
      # @param config [Hash] channel configuration for broadcast, presence, and postgres_changes
      def initialize(topic, client:, config: {})
        @topic = topic
        @client = client
        @config = config
        @state = :closed
        @join_ref = nil
        @bindings = []
        @push_buffer = []
        @access_token = client.access_token
        @subscribe_callback = nil
        @presence = Presence.new
      end

      # Subscribes to this channel by sending a join request to the server.
      #
      # @yield [status, error] called when the channel join completes or fails
      # @yieldparam status [Symbol] the subscription status
      # @yieldparam error [Hash, nil] error details if the join failed
      # @return [self]
      def subscribe(&callback)
        @state = :joining
        @join_ref = @client.make_ref
        @client.push(build_join_push)
        @subscribe_callback = callback
        self
      end

      # Unsubscribes from this channel by sending a leave request to the server.
      #
      # @return [self]
      def unsubscribe
        @state = :leaving
        @client.push(build_leave_push)
        @state = :closed
        self
      end

      # Rejoins the channel after a reconnection. No-op if channel is closed.
      #
      # @return [void]
      def rejoin
        return if @state == :closed

        @state = :joining
        @join_ref = @client.make_ref
        @client.push(build_join_push)
      end

      # Updates the access token used for authentication on this channel.
      #
      # @param token [String] the new JWT access token
      # @return [void]
      def update_access_token(token)
        @access_token = token
      end

      private

      def build_join_push
        {
          "topic" => @topic,
          "event" => "phx_join",
          "payload" => build_join_payload,
          "ref" => @join_ref,
          "join_ref" => @join_ref
        }
      end

      def build_join_payload
        payload = { "config" => build_channel_config }
        payload["access_token"] = @access_token if @access_token
        payload
      end

      def build_channel_config
        config = @config.dup
        config["broadcast"] ||= {}
        config["presence"] ||= {}
        config["postgres_changes"] = build_postgres_changes_config
        config
      end

      def build_postgres_changes_config
        @bindings.select { |b| b[:type] == :postgres_changes }.map do |binding|
          pg_config = { "event" => binding[:event], "schema" => binding[:schema] }
          pg_config["table"] = binding[:table] if binding[:table]
          pg_config["filter"] = binding[:filter] if binding[:filter]
          pg_config
        end
      end

      def build_leave_push
        {
          "topic" => @topic,
          "event" => "phx_leave",
          "payload" => {},
          "ref" => @client.make_ref,
          "join_ref" => @join_ref
        }
      end
    end
  end
end
