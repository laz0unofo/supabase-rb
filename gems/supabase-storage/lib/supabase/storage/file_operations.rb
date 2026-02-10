# frozen_string_literal: true

module Supabase
  module Storage
    # File upload, download, move, copy, remove, info, and exists operations.
    module FileOperations
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

      def download(path, transform: nil)
        normalized = normalize_path(path)
        url = build_download_url(normalized, transform)
        response = perform_request(:get, url, nil, @headers.dup)
        return api_error_result(response) unless (200..299).cover?(response.status)

        { data: response.body, error: nil }
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

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

      def remove(paths)
        response = perform_json_request(:delete, "#{@url}/object/#{@bucket_id}", { prefixes: paths })
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

      def info(path)
        normalized = normalize_path(path)
        url = "#{@url}/object/info/#{@bucket_id}/#{normalized}"
        response = perform_request(:get, url, nil, @headers.dup)
        handle_response(response)
      rescue Faraday::Error => e
        unknown_error_result(e)
      end

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
