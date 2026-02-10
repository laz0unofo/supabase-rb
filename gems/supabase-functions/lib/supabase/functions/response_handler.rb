# frozen_string_literal: true

require "json"

module Supabase
  module Functions
    # Handles processing of HTTP responses from Edge Functions.
    module ResponseHandler
      private

      def process_response(response)
        return relay_error_result(response) if response.headers["x-relay-error"] == "true"
        return http_error_result(response) unless (200..299).cover?(response.status)

        { data: parse_response(response), error: nil }
      end

      def relay_error_result(response)
        { data: nil, error: FunctionsRelayError.new(response.body, status: response.status, context: response) }
      end

      def http_error_result(response)
        { data: nil, error: FunctionsHttpError.new(response.body, status: response.status, context: response) }
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
