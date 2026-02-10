# frozen_string_literal: true

require "json"

module Supabase
  module Functions
    # Handles processing of HTTP responses from Edge Functions.
    # Raises appropriate error classes on failures.
    module ResponseHandler
      private

      def process_response(response)
        raise_relay_error(response) if response.headers["x-relay-error"] == "true"
        raise_http_error(response) unless (200..299).cover?(response.status)

        parse_response(response)
      end

      def raise_relay_error(response)
        raise FunctionsRelayError.new(response.body, status: response.status, context: response)
      end

      def raise_http_error(response)
        raise FunctionsHttpError.new(response.body, status: response.status, context: response)
      end

      def parse_response(response)
        content_type = response.headers["content-type"].to_s

        if content_type.include?("application/json")
          JSON.parse(response.body)
        elsif content_type.include?("application/octet-stream")
          response.body.b
        elsif content_type.include?("text/event-stream")
          response
        else
          response.body
        end
      end
    end
  end
end
