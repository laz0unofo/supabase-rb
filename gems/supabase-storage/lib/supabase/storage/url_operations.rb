# frozen_string_literal: true

require "uri"

module Supabase
  module Storage
    # Signed URL generation, public URL construction, and file listing operations.
    module UrlOperations
      # Creates a signed URL for temporary access to a file.
      #
      # @param path [String] the file path within the bucket
      # @param expires_in [Integer] expiration time in seconds
      # @param download [Boolean, String, nil] triggers download; pass a String to set the filename
      # @param transform [Hash, nil] optional image transformation parameters
      # @return [Hash] { data: { signed_url: String }, error: nil }
      #   on success, { data: nil, error: StorageApiError } on failure
      def create_signed_url(path, expires_in, download: nil, transform: nil)
        normalized = normalize_path(path)
        body = { expiresIn: expires_in }
        body[:transform] = transform if transform
        response = perform_json_request(:post, "#{@url}/object/sign/#{@bucket_id}/#{normalized}", body)
        return handle_response(response) unless (200..299).cover?(response.status)

        data = parse_json(response.body)
        { data: { signed_url: build_full_signed_url(data["signedURL"], download) }, error: nil }
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Creates signed URLs for multiple files in a single request.
      #
      # @param paths [Array<String>] list of file paths within the bucket
      # @param expires_in [Integer] expiration time in seconds
      # @param download [Boolean, String, nil] triggers download; pass a String to set the filename
      # @return [Hash] { data: Array<Hash>, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def create_signed_urls(paths, expires_in, download: nil)
        body = { expiresIn: expires_in, paths: paths.map { |p| "#{@bucket_id}/#{normalize_path(p)}" } }
        response = perform_json_request(:post, "#{@url}/object/sign", body)
        return handle_response(response) unless (200..299).cover?(response.status)

        data = parse_json(response.body)
        { data: data.map { |item| build_signed_url_item(item, download) }, error: nil }
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Creates a signed URL for uploading a file without authentication.
      #
      # @param path [String] the file path within the bucket
      # @param upsert [Boolean] whether to overwrite an existing file (default: false)
      # @return [Hash] { data: { signed_url: String, token: String, path: String }, error: nil } on success
      def create_signed_upload_url(path, upsert: false)
        normalized = normalize_path(path)
        url = "#{@url}/object/upload/sign/#{@bucket_id}/#{normalized}"
        headers = @headers.merge("Content-Type" => "application/json")
        headers["x-upsert"] = "true" if upsert
        response = perform_request(:post, url, nil, headers)
        return handle_response(response) unless (200..299).cover?(response.status)

        data = parse_json(response.body)
        { data: { signed_url: "#{@url}#{data["url"]}", token: data["token"], path: normalized }, error: nil }
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Uploads a file using a previously created signed upload URL.
      #
      # @param path [String] the file path within the bucket
      # @param token [String] the upload token from create_signed_upload_url
      # @param body [String, IO, StringIO] the file content to upload
      # @option options [String] :content_type MIME type of the file (default: "application/octet-stream")
      # @option options [String, Integer] :cache_control max-age cache control value (default: "3600")
      # @option options [Boolean] :upsert whether to overwrite an existing file
      # @option options [Hash] :metadata custom metadata for the file
      # @return [Hash] { data: Hash, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def upload_to_signed_url(path, token, body, **options)
        normalized = normalize_path(path)
        url = "#{@url}/object/upload/sign/#{@bucket_id}/#{normalized}?token=#{URI.encode_www_form_component(token)}"
        headers = build_upload_headers(options)
        headers["x-upsert"] = options[:upsert] ? "true" : "false"
        response = perform_request(:put, url, read_body(body), headers)
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Constructs a public URL for a file in a public bucket.
      #
      # @param path [String] the file path within the bucket
      # @param download [Boolean, String, nil] triggers download; pass a String to set the filename
      # @param transform [Hash, nil] optional image transformation parameters
      # @return [Hash] { data: { public_url: String }, error: nil }
      def get_public_url(path, download: nil, transform: nil)
        normalized = normalize_path(path)
        base = transform ? "render/image/public" : "object/public"
        url = append_query_params("#{@url}/#{base}/#{@bucket_id}/#{normalized}", download, transform)
        { data: { public_url: url }, error: nil }
      end

      # Lists files in the bucket under the given path.
      #
      # @param path [String, nil] folder path to list (defaults to root)
      # @option options [Integer] :limit maximum number of results (default: 100)
      # @option options [Integer] :offset number of results to skip (default: 0)
      # @option options [Hash] :sort_by sorting options with :column and :order keys
      # @option options [String] :search filter files by name prefix
      # @return [Hash] { data: Array<Hash>, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def list(path = nil, **options)
        body = build_list_body(path, options)
        response = perform_json_request(:post, "#{@url}/object/list/#{@bucket_id}", body)
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      private

      def build_full_signed_url(signed_path, download)
        url = "#{@url}#{signed_path}"
        return url unless download

        separator = url.include?("?") ? "&" : "?"
        "#{url}#{separator}#{build_download_param(download)}"
      end

      def build_download_param(download)
        download.is_a?(String) ? "download=#{URI.encode_www_form_component(download)}" : "download="
      end

      def build_signed_url_item(item, download)
        result = { path: item["path"], error: item["error"] }
        result[:signed_url] = build_full_signed_url(item["signedURL"], download) if item["signedURL"]
        result
      end

      def append_query_params(url, download, transform)
        params = []
        params.concat(transform.map { |k, v| "#{k}=#{v}" }) if transform
        params << build_download_param(download) if download
        return url if params.empty?

        "#{url}?#{params.join("&")}"
      end

      def build_list_body(path, options)
        body = {
          prefix: normalize_path(path || ""),
          limit: options.fetch(:limit, 100),
          offset: options.fetch(:offset, 0),
          sortBy: options.fetch(:sort_by, { column: "name", order: "asc" })
        }
        body[:search] = options[:search] if options[:search]
        body
      end
    end
  end
end
