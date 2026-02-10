# frozen_string_literal: true

module Supabase
  module Realtime
    # Represents a push (outgoing message) that can receive a reply.
    class Push
      attr_reader :channel, :event, :payload, :ref, :timeout

      def initialize(channel:, event:, payload: {}, timeout: 10_000)
        @channel = channel
        @event = event
        @payload = payload
        @timeout = timeout
        @ref = nil
        @received_reply = nil
        @reply_callbacks = Hash.new { |h, k| h[k] = [] }
      end

      def send_message
        @ref = @channel.client.make_ref
        @channel.client.push(build_message)
        self
      end

      def receive(status, &callback)
        @reply_callbacks[status.to_s] << callback
        trigger_reply if @received_reply
        self
      end

      def trigger(reply_status, response)
        @received_reply = { status: reply_status, response: response }
        trigger_reply
      end

      private

      def build_message
        {
          "topic" => @channel.topic,
          "event" => @event,
          "payload" => @payload,
          "ref" => @ref,
          "join_ref" => @channel.join_ref
        }
      end

      def trigger_reply
        return unless @received_reply

        status = @received_reply[:status].to_s
        @reply_callbacks[status].each do |callback|
          callback.call(@received_reply[:response])
        end
      end
    end
  end
end
