# frozen_string_literal: true

require "faraday"
require "json"
require_relative "file_operations"
require_relative "url_operations"

module Supabase
  module Storage
    # API for file operations within a specific storage bucket.
    # Provides upload, download, move, copy, delete, list, and URL generation.
    class StorageFileApi
      include FileOperations
      include UrlOperations

      def initialize(url:, bucket_id:, headers: {}, fetch: nil)
        @url = url.to_s.chomp("/")
        @headers = headers.dup
        @bucket_id = bucket_id
        @fetch = fetch
      end

      attr_reader :bucket_id

      private

      def normalize_path(path)
        path.to_s.gsub(%r{/+}, "/").gsub(%r{^/|/$}, "")
      end

      def build_upload_headers(options)
        headers = @headers.dup
        headers["cache-control"] = "max-age=#{options.fetch(:cache_control, "3600")}"
        headers["content-type"] = options[:content_type] || "application/octet-stream"
        headers["x-upsert"] = "true" if options[:upsert]
        headers["x-metadata"] = JSON.generate(options[:metadata]) if options[:metadata]
        headers
      end

      def read_body(body)
        case body
        when IO, StringIO then body.read
        else body.to_s
        end
      end

      def build_download_url(normalized_path, transform)
        if transform
          params = build_transform_params(transform)
          "#{@url}/render/image/authenticated/#{@bucket_id}/#{normalized_path}?#{params}"
        else
          "#{@url}/object/#{@bucket_id}/#{normalized_path}"
        end
      end

      def build_transform_params(transform)
        transform.map { |key, value| "#{key}=#{value}" }.join("&")
      end

      def perform_request(method, url, body, headers)
        build_connection.run_request(method, url, body, headers)
      end

      def perform_json_request(method, url, body)
        headers = @headers.merge("Content-Type" => "application/json")
        perform_request(method, url, JSON.generate(body), headers)
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

      def unknown_error_result(err)
        { data: nil, error: StorageUnknownError.new(err.message, context: err) }
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
