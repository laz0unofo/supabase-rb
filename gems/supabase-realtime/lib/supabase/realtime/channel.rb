# frozen_string_literal: true

module Supabase
  module Realtime
    # Represents a channel subscription on the Realtime server.
    # Full channel API (broadcast, presence, postgres_changes) is in US-022.
    class RealtimeChannel
      include ChannelMessageHandler

      STATES = %i[closed joining joined leaving].freeze

      attr_reader :topic, :client, :state, :join_ref

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
      end

      def subscribe(&callback)
        @state = :joining
        @join_ref = @client.make_ref
        @client.push(build_join_push)
        @subscribe_callback = callback
        self
      end

      def unsubscribe
        @state = :leaving
        @client.push(build_leave_push)
        @state = :closed
        self
      end

      def rejoin
        return if @state == :closed

        @state = :joining
        @join_ref = @client.make_ref
        @client.push(build_join_push)
      end

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
        payload = { "config" => @config }
        payload["access_token"] = @access_token if @access_token
        payload
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
