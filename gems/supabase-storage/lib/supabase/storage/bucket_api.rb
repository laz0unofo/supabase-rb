# frozen_string_literal: true

module Supabase
  module Storage
    # Bucket management methods for the Storage client.
    module BucketApi
      def list_buckets(**options)
        body = build_list_buckets_body(options)
        response = perform_request(:get, "#{@url}/bucket", body)
        handle_response(response)
      rescue Faraday::Error => e
        { data: nil, error: StorageUnknownError.new(e.message, context: e) }
      end

      def get_bucket(bucket_id)
        response = perform_request(:get, "#{@url}/bucket/#{bucket_id}", nil)
        handle_response(response)
      rescue Faraday::Error => e
        { data: nil, error: StorageUnknownError.new(e.message, context: e) }
      end

      def create_bucket(bucket_id, **options)
        body = { id: bucket_id, name: bucket_id }
        body[:public] = options[:public] if options.key?(:public)
        body[:file_size_limit] = options[:file_size_limit] if options[:file_size_limit]
        body[:allowed_mime_types] = options[:allowed_mime_types] if options[:allowed_mime_types]
        response = perform_request(:post, "#{@url}/bucket", JSON.generate(body))
        handle_response(response)
      rescue Faraday::Error => e
        { data: nil, error: StorageUnknownError.new(e.message, context: e) }
      end

      def update_bucket(bucket_id, **options)
        body = { public: options[:public] }
        body[:file_size_limit] = options[:file_size_limit] if options[:file_size_limit]
        body[:allowed_mime_types] = options[:allowed_mime_types] if options[:allowed_mime_types]
        response = perform_request(:put, "#{@url}/bucket/#{bucket_id}", JSON.generate(body))
        handle_response(response)
      rescue Faraday::Error => e
        { data: nil, error: StorageUnknownError.new(e.message, context: e) }
      end

      def empty_bucket(bucket_id)
        response = perform_request(:post, "#{@url}/bucket/#{bucket_id}/empty", JSON.generate({}))
        handle_response(response)
      rescue Faraday::Error => e
        { data: nil, error: StorageUnknownError.new(e.message, context: e) }
      end

      def delete_bucket(bucket_id)
        response = perform_request(:delete, "#{@url}/bucket/#{bucket_id}", JSON.generate({}))
        handle_response(response)
      rescue Faraday::Error => e
        { data: nil, error: StorageUnknownError.new(e.message, context: e) }
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
