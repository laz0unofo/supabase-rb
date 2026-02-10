# frozen_string_literal: true

module Supabase
  module Storage
    # File upload, download, move, copy, remove, info, and exists operations.
    module FileOperations
      # Uploads a file to the bucket.
      #
      # @param path [String] the file path within the bucket
      # @param body [String, IO, StringIO] the file content to upload
      # @option options [String] :content_type MIME type of the file (default: "application/octet-stream")
      # @option options [String, Integer] :cache_control max-age cache control value (default: "3600")
      # @option options [Boolean] :upsert whether to overwrite an existing file
      # @option options [Hash] :metadata custom metadata for the file
      # @return [Hash] { data: Hash, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def upload(path, body, **options)
        normalized = normalize_path(path)
        url = "#{@url}/object/#{@bucket_id}/#{normalized}"
        headers = build_upload_headers(options)
        raw_body = read_body(body)
        response = perform_request(:post, url, raw_body, headers)
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Updates an existing file in the bucket.
      #
      # @param path [String] the file path within the bucket
      # @param body [String, IO, StringIO] the new file content
      # @option options [String] :content_type MIME type of the file (default: "application/octet-stream")
      # @option options [String, Integer] :cache_control max-age cache control value (default: "3600")
      # @option options [Boolean] :upsert whether to overwrite an existing file
      # @option options [Hash] :metadata custom metadata for the file
      # @return [Hash] { data: Hash, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def update(path, body, **options)
        normalized = normalize_path(path)
        url = "#{@url}/object/#{@bucket_id}/#{normalized}"
        headers = build_upload_headers(options)
        raw_body = read_body(body)
        response = perform_request(:put, url, raw_body, headers)
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Downloads a file from the bucket.
      #
      # @param path [String] the file path within the bucket
      # @param transform [Hash, nil] optional image transformation parameters
      # @return [Hash] { data: String, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def download(path, transform: nil)
        normalized = normalize_path(path)
        url = build_download_url(normalized, transform)
        response = perform_request(:get, url, nil, @headers.dup)
        return api_error_result(response) unless (200..299).cover?(response.status)

        { data: response.body, error: nil }
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Moves a file from one path to another, optionally across buckets.
      #
      # @param from_path [String] the source file path
      # @param to_path [String] the destination file path
      # @param destination_bucket [String, nil] target bucket ID (defaults to current bucket)
      # @return [Hash] { data: Hash, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def move(from_path, to_path, destination_bucket: nil)
        body = {
          bucketId: @bucket_id,
          sourceKey: from_path,
          destinationBucket: destination_bucket || @bucket_id,
          destinationKey: to_path
        }
        response = perform_json_request(:post, "#{@url}/object/move", body)
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Copies a file from one path to another, optionally across buckets.
      #
      # @param from_path [String] the source file path
      # @param to_path [String] the destination file path
      # @param destination_bucket [String, nil] target bucket ID (defaults to current bucket)
      # @return [Hash] { data: Hash, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def copy(from_path, to_path, destination_bucket: nil)
        body = {
          bucketId: @bucket_id,
          sourceKey: from_path,
          destinationBucket: destination_bucket || @bucket_id,
          destinationKey: to_path
        }
        response = perform_json_request(:post, "#{@url}/object/copy", body)
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Removes one or more files from the bucket.
      #
      # @param paths [Array<String>] list of file paths to remove
      # @return [Hash] { data: Hash, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def remove(paths)
        response = perform_json_request(:delete, "#{@url}/object/#{@bucket_id}", { prefixes: paths })
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Retrieves metadata for a file in the bucket.
      #
      # @param path [String] the file path within the bucket
      # @return [Hash] { data: Hash, error: nil } on success, { data: nil, error: StorageApiError } on failure
      def info(path)
        normalized = normalize_path(path)
        url = "#{@url}/object/info/#{@bucket_id}/#{normalized}"
        response = perform_request(:get, url, nil, @headers.dup)
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      # Checks whether a file exists in the bucket.
      #
      # @param path [String] the file path within the bucket
      # @return [Hash] { data: Boolean, error: nil } on success, { data: nil, error: StorageUnknownError } on failure
      def exists?(path)
        normalized = normalize_path(path)
        url = "#{@url}/object/#{@bucket_id}/#{normalized}"
        response = perform_request(:head, url, nil, @headers.dup)
        { data: (200..299).cover?(response.status), error: nil }
      rescue Faraday::Error => e
        unknown_error_result(e)
      end
    end
  end
end
