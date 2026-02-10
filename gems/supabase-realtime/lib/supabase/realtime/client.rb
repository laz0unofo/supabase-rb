# frozen_string_literal: true

require "uri"
require "json"
require "websocket-client-simple"

module Supabase
  module Realtime
    # WebSocket client for Supabase Realtime with heartbeat, reconnection,
    # send buffer, and channel management.
    class Client # rubocop:disable Metrics/ClassLength
      include Heartbeat
      include Reconnect

      STATES = %i[closed connecting open closing].freeze
      REJOIN_STATES = %i[joined joining].freeze
      VSN = "1.0.0"

      attr_reader :state, :channels, :endpoint_url, :http_broadcast_url, :access_token

      # Creates a new Realtime WebSocket client.
      #
      # @param url [String] the Realtime server WebSocket URL
      # @param options [Hash] connection options
      # @option options [Hash] :params connection parameters (must include :apikey)
      # @option options [Integer] :timeout connection timeout in milliseconds (default: 10_000)
      # @option options [Integer] :heartbeat_interval_ms heartbeat interval in milliseconds (default: 25_000)
      # @option options [Proc, nil] :reconnect_after_ms custom reconnection delay strategy
      # @option options [Logger, nil] :logger logger instance for debug output
      # @option options [String, nil] :access_token JWT access token for authentication
      # @raise [ArgumentError] if params[:apikey] is missing
      def initialize(url, **options)
        validate_params!(options)
        assign_options(url, options)
        init_state
        @endpoint_url = build_endpoint_url
        @http_broadcast_url = derive_http_broadcast_url
      end

      # Opens the WebSocket connection to the Realtime server.
      # No-op if already connecting or connected.
      #
      # @return [void]
      def connect
        return if @state == :connecting || @state == :open

        do_connect
      end

      # Gracefully closes the WebSocket connection, stopping heartbeat and reconnection.
      # No-op if already closed.
      #
      # @return [void]
      def disconnect
        return if @state == :closed

        @state = :closing
        stop_heartbeat
        reset_reconnect
        close_websocket
        @state = :closed
        log(:info, "disconnected")
      end

      # Creates a new channel subscription and registers it with this client.
      #
      # @param name [String] the channel name (will be prefixed with "realtime:")
      # @param config [Hash] channel configuration (broadcast, presence, postgres_changes)
      # @return [RealtimeChannel] the newly created channel
      def channel(name, config: {})
        topic = "realtime:#{name}"
        chan = RealtimeChannel.new(topic, client: self, config: config)
        @channels << chan
        chan
      end

      # Sets the authentication token and propagates it to all channels.
      #
      # @param token [String] the new JWT access token
      # @return [void]
      # rubocop:disable Naming/AccessorMethodName
      def set_auth(token)
        @access_token = token
        @channels.each { |ch| ch.update_access_token(token) }
      end
      # rubocop:enable Naming/AccessorMethodName

      # Removes a channel, unsubscribing it first if currently joined.
      #
      # @param channel [RealtimeChannel] the channel to remove
      # @return [RealtimeChannel, nil] the removed channel, or nil if not found
      def remove_channel(channel)
        channel.unsubscribe if channel.state == :joined
        @channels.delete(channel)
      end

      # Removes all channels, unsubscribing any that are currently joined.
      #
      # @return [void]
      def remove_all_channels
        @channels.each { |ch| ch.unsubscribe if ch.state == :joined }
        @channels.clear
      end

      # Returns a copy of all registered channels.
      #
      # @return [Array<RealtimeChannel>] a duplicate of the channels list
      # rubocop:disable Naming/AccessorMethodName
      def get_channels
        @channels.dup
      end
      # rubocop:enable Naming/AccessorMethodName

      # Generates a unique, incrementing reference string for message tracking.
      #
      # @return [String] the next reference identifier
      def make_ref
        @mutex.synchronize do
          @ref_counter += 1
          @ref_counter.to_s
        end
      end

      # Sends a message through the WebSocket, or buffers it if not connected.
      #
      # @param message [Hash] the message payload to send
      # @return [void]
      def push(message)
        encoded = Serializer.encode(message)
        if @state == :open && @ws
          @ws.send(encoded)
        else
          @send_buffer << encoded
        end
      end

      # Logs a message with the given severity level, prefixed with "[Realtime]".
      #
      # @param level [Symbol] the log level (:info, :warn, :error, :debug)
      # @param message [String] the message to log
      # @return [void]
      def log(level, message)
        @logger&.send(level, "[Realtime] #{message}")
      end

      private

      def assign_options(url, options)
        @url = url
        @params = options.fetch(:params, {})
        @timeout = options.fetch(:timeout, 10_000)
        @heartbeat_interval_ms = options.fetch(:heartbeat_interval_ms, 25_000)
        @reconnect_after_ms = options.fetch(:reconnect_after_ms, nil)
        @logger = options.fetch(:logger, nil)
        @access_token = options.fetch(:access_token, nil)
      end

      def init_state
        @state = :closed
        @channels = []
        @send_buffer = []
        @ref_counter = 0
        @ws = nil
        @mutex = Mutex.new
      end

      def validate_params!(options)
        params = options.fetch(:params, {})
        return if params[:apikey] || params["apikey"]

        raise ArgumentError, "params[:apikey] is required"
      end

      def build_endpoint_url
        uri = URI.parse(@url)
        uri.path = "#{uri.path.chomp("/")}/socket/websocket"
        uri
      end

      def derive_http_broadcast_url
        url_str = @url.to_s
        url_str = url_str.sub("ws://", "http://").sub("wss://", "https://")
        uri = URI.parse(url_str)
        base_path = uri.path.sub(%r{/socket/websocket.*}, "").sub(%r{/realtime/v1.*}, "")
        uri.path = "#{base_path}/api/broadcast"
        uri.query = nil
        uri.to_s
      end

      def do_connect
        @state = :connecting
        ws_url = build_ws_url
        log(:info, "connecting to #{ws_url}")
        @ws = establish_websocket(ws_url)
      rescue StandardError => e
        @state = :closed
        log(:error, "connection failed: #{e.message}")
        reconnect
      end

      def establish_websocket(ws_url)
        client_ref = self
        WebSocket::Client::Simple.connect(ws_url) do |ws|
          ws.on :open do
            client_ref.send(:on_ws_open)
          end

          ws.on :message do |msg|
            client_ref.send(:on_ws_message, msg.data)
          end

          ws.on :close do |event|
            client_ref.send(:on_ws_close, event)
          end

          ws.on :error do |event|
            client_ref.send(:on_ws_error, event)
          end
        end
      end

      def build_ws_url
        uri = @endpoint_url.dup
        params = { "apikey" => @params[:apikey] || @params["apikey"], "vsn" => VSN }
        uri.query = URI.encode_www_form(params)
        uri.to_s
      end

      def on_ws_open
        @state = :open
        reset_reconnect
        start_heartbeat
        flush_send_buffer
        rejoin_channels
        log(:info, "connected")
      end

      def on_ws_message(raw)
        message = Serializer.decode(raw)
        return unless message

        handle_message(message)
      end

      def on_ws_close(_event)
        return if @state == :closing

        @state = :closed
        stop_heartbeat
        log(:info, "connection closed, will reconnect")
        reconnect
      end

      def on_ws_error(event)
        log(:error, "websocket error: #{event}")
      end

      def handle_message(message)
        topic = message["topic"]
        event = message["event"]
        ref = message["ref"]

        if topic == Heartbeat::PHOENIX_TOPIC && event == "phx_reply"
          handle_heartbeat_reply(ref)
          return
        end

        route_to_channel(message)
      end

      def route_to_channel(message)
        topic = message["topic"]
        @channels.each do |channel|
          channel.handle_message(message) if channel.topic == topic
        end
      end

      def flush_send_buffer
        @send_buffer.each { |msg| @ws&.send(msg) }
        @send_buffer.clear
      end

      def rejoin_channels
        @channels.each do |channel|
          channel.rejoin if REJOIN_STATES.include?(channel.state)
        end
      end

      def apikey
        @params[:apikey] || @params["apikey"]
      end

      def close_websocket
        @ws&.close
      rescue StandardError => e
        log(:warn, "error closing websocket: #{e.message}")
      ensure
        @ws = nil
      end
    end
  end
end
