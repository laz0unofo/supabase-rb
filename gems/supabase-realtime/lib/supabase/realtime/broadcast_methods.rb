# frozen_string_literal: true

require "faraday"
require "json"

module Supabase
  module Realtime
    # Broadcast registration and sending methods for RealtimeChannel.
    module BroadcastMethods
      def on_broadcast(event, &callback)
        @bindings << { type: :broadcast, event: event, callback: callback }
        self
      end

      def send_broadcast(event:, payload: {}, type: :websocket)
        if type == :http
          send_http_broadcast(event, payload)
        else
          send_ws_broadcast(event, payload)
        end
      end

      private

      def send_ws_broadcast(event, payload)
        message = {
          "topic" => @topic,
          "event" => "broadcast",
          "payload" => {
            "event" => event,
            "payload" => payload,
            "type" => "broadcast"
          },
          "ref" => @client.make_ref,
          "join_ref" => @join_ref
        }
        @client.push(message)
      end

      def send_http_broadcast(event, payload)
        body = build_http_broadcast_body(event, payload)
        headers = build_http_broadcast_headers

        conn = Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end

        conn.post(@client.http_broadcast_url) do |req|
          req.headers = headers
          req.body = JSON.generate(body)
        end
      end

      def build_http_broadcast_body(event, payload)
        {
          "messages" => [{
            "topic" => @topic,
            "event" => event,
            "payload" => payload
          }]
        }
      end

      def build_http_broadcast_headers
        apikey = @client.send(:apikey)
        {
          "Content-Type" => "application/json",
          "apikey" => apikey,
          "Authorization" => "Bearer #{@access_token || apikey}"
        }
      end
    end
  end
end
