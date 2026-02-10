# frozen_string_literal: true

require "faraday"
require "json"
require_relative "bucket_api"
require_relative "storage_file_api"

module Supabase
  module Storage
    # Client for Supabase Storage bucket management and file operations.
    class Client
      include BucketApi

      def initialize(url:, headers: {}, fetch: nil)
        @url = url.to_s.chomp("/")
        @headers = headers.dup
        @fetch = fetch
      end

      def from(bucket_id)
        StorageFileApi.new(
          url: @url,
          headers: @headers.dup,
          bucket_id: bucket_id,
          fetch: @fetch
        )
      end

      private

      def perform_request(method, url, body)
        connection = build_connection
        headers = @headers.merge("Content-Type" => "application/json")
        connection.run_request(method, url, body, headers)
      end

      def build_connection
        return @fetch.call if @fetch

        Faraday.new do |f|
          f.adapter Faraday.default_adapter
        end
      end

      def handle_response(response)
        return api_error_result(response) unless (200..299).cover?(response.status)

        { data: parse_json(response.body), error: nil }
      end

      def api_error_result(response)
        message = extract_error_message(response)
        { data: nil, error: StorageApiError.new(message, status: response.status, context: response) }
      end

      def extract_error_message(response)
        parsed = JSON.parse(response.body)
        parsed["message"] || parsed["error"] || response.body
      rescue JSON::ParserError
        response.body
      end

      def parse_json(body)
        return nil if body.nil? || body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        body
      end
    end
  end
end
