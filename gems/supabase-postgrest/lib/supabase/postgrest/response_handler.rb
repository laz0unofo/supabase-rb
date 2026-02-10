# frozen_string_literal: true

require "json"

module Supabase
  module PostgREST
    # Handles parsing of PostgREST HTTP responses into Response objects.
    # Raises PostgrestError on non-2xx responses and network failures.
    module ResponseHandler
      private

      def build_result(response)
        raise_on_error(response)

        Response.new(
          data: parse_data(response),
          count: parse_count(response),
          status: response.status,
          status_text: response.reason_phrase || ""
        )
      end

      def raise_on_error(response)
        return if (200..299).cover?(response.status)

        body = parse_json_safe(response.body)
        raise PostgrestError.new(response.body, status: response.status) unless body.is_a?(Hash)

        raise PostgrestError.new(
          body["message"],
          status: response.status,
          details: body["details"],
          hint: body["hint"],
          code: body["code"]
        )
      end

      def parse_data(response)
        content_type = response.headers["content-type"].to_s
        if content_type.include?("application/json") || content_type.include?("application/vnd.pgrst")
          parse_json_safe(response.body)
        else
          response.body
        end
      end

      def parse_count(response)
        range = response.headers["content-range"]
        return nil unless range

        parts = range.split("/")
        count_str = parts.last
        return nil if count_str.nil? || count_str == "*"

        Integer(count_str, exception: false)
      end

      def parse_json_safe(body)
        return nil if body.nil? || body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        body
      end

      def handle_fetch_error(error)
        raise PostgrestError.new(error.message, status: 0, code: "FETCH_ERROR", context: error)
      end
    end
  end
end
