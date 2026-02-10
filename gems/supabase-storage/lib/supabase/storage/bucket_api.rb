# frozen_string_literal: true

module Supabase
  module Storage
    # Bucket management methods for the Storage client.
    module BucketApi
      # Lists all storage buckets.
      #
      # @option options [Integer] :limit maximum number of results
      # @option options [Integer] :offset number of results to skip
      # @option options [Hash] :sort_by sorting options
      # @option options [String] :search filter buckets by name
      # @return [Array] list of bucket hashes on success
      # @raise [StorageApiError] on HTTP error
      # @raise [StorageUnknownError] on network failure
      def list_buckets(**options)
        body = build_list_buckets_body(options)
        response = perform_request(:get, "#{@url}/bucket", body)
        handle_response(response)
      rescue Faraday::Error => e
        raise StorageUnknownError.new(e.message, context: e)
      end

      # Retrieves details of a single bucket.
      #
      # @param bucket_id [String] the bucket identifier
      # @return [Hash] response data on success
      # @raise [StorageApiError] on HTTP error
      # @raise [StorageUnknownError] on network failure
      def get_bucket(bucket_id)
        response = perform_request(:get, "#{@url}/bucket/#{bucket_id}", nil)
        handle_response(response)
      rescue Faraday::Error => e
        raise StorageUnknownError.new(e.message, context: e)
      end

      # Creates a new storage bucket.
      #
      # @param bucket_id [String] the bucket identifier (also used as the bucket name)
      # @option options [Boolean] :public whether the bucket is publicly accessible
      # @option options [Integer] :file_size_limit maximum file size in bytes
      # @option options [Array<String>] :allowed_mime_types list of permitted MIME types
      # @return [Hash] response data on success
      # @raise [StorageApiError] on HTTP error
      # @raise [StorageUnknownError] on network failure
      def create_bucket(bucket_id, **options)
        body = { id: bucket_id, name: bucket_id }
        body[:public] = options[:public] if options.key?(:public)
        body[:file_size_limit] = options[:file_size_limit] if options[:file_size_limit]
        body[:allowed_mime_types] = options[:allowed_mime_types] if options[:allowed_mime_types]
        response = perform_request(:post, "#{@url}/bucket", JSON.generate(body))
        handle_response(response)
      rescue Faraday::Error => e
        raise StorageUnknownError.new(e.message, context: e)
      end

      # Updates an existing storage bucket's configuration.
      #
      # @param bucket_id [String] the bucket identifier
      # @option options [Boolean] :public whether the bucket is publicly accessible
      # @option options [Integer] :file_size_limit maximum file size in bytes
      # @option options [Array<String>] :allowed_mime_types list of permitted MIME types
      # @return [Hash] response data on success
      # @raise [StorageApiError] on HTTP error
      # @raise [StorageUnknownError] on network failure
      def update_bucket(bucket_id, **options)
        body = { public: options[:public] }
        body[:file_size_limit] = options[:file_size_limit] if options[:file_size_limit]
        body[:allowed_mime_types] = options[:allowed_mime_types] if options[:allowed_mime_types]
        response = perform_request(:put, "#{@url}/bucket/#{bucket_id}", JSON.generate(body))
        handle_response(response)
      rescue Faraday::Error => e
        raise StorageUnknownError.new(e.message, context: e)
      end

      # Removes all files from a bucket without deleting the bucket itself.
      #
      # @param bucket_id [String] the bucket identifier
      # @return [Hash] response data on success
      # @raise [StorageApiError] on HTTP error
      # @raise [StorageUnknownError] on network failure
      def empty_bucket(bucket_id)
        response = perform_request(:post, "#{@url}/bucket/#{bucket_id}/empty", JSON.generate({}))
        handle_response(response)
      rescue Faraday::Error => e
        raise StorageUnknownError.new(e.message, context: e)
      end

      # Deletes a storage bucket. The bucket must be empty first.
      #
      # @param bucket_id [String] the bucket identifier
      # @return [Hash] response data on success
      # @raise [StorageApiError] on HTTP error
      # @raise [StorageUnknownError] on network failure
      def delete_bucket(bucket_id)
        response = perform_request(:delete, "#{@url}/bucket/#{bucket_id}", JSON.generate({}))
        handle_response(response)
      rescue Faraday::Error => e
        raise StorageUnknownError.new(e.message, context: e)
      end

      private

      def build_list_buckets_body(options)
        return nil if options.empty?

        body = {}
        body[:limit] = options[:limit] if options[:limit]
        body[:offset] = options[:offset] if options[:offset]
        body[:sort_by] = options[:sort_by] if options[:sort_by]
        body[:search] = options[:search] if options[:search]
        body.empty? ? nil : JSON.generate(body)
      end
    end
  end
end
