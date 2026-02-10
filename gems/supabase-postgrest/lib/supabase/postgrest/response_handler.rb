# frozen_string_literal: true

require "json"

module Supabase
  module PostgREST
    # Handles parsing of PostgREST HTTP responses into result hashes.
    module ResponseHandler
      private

      def build_result(response)
        error = parse_error(response)
        raise error if error && @throw_on_error

        {
          data: error ? nil : parse_data(response),
          error: error,
          count: parse_count(response),
          status: response.status,
          status_text: response.reason_phrase || ""
        }
      end

      def parse_error(response)
        return nil if (200..299).cover?(response.status)

        body = parse_json_safe(response.body)
        if body.is_a?(Hash)
          PostgrestError.new(body["message"], details: body["details"], hint: body["hint"], code: body["code"])
        else
          PostgrestError.new(response.body)
        end
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
        pg_error = PostgrestError.new(error.message, code: "FETCH_ERROR")
        raise pg_error if @throw_on_error

        { data: nil, error: pg_error, count: nil, status: 0, status_text: "" }
      end
    end
  end
end
