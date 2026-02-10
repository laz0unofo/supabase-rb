# frozen_string_literal: true

module Supabase
  module Storage
    # API for file operations within a specific storage bucket.
    # Provides upload, download, move, copy, delete, list, and URL generation.
    class StorageFileApi
      def initialize(url:, bucket_id:, headers: {}, fetch: nil)
        @url = url.to_s.chomp("/")
        @headers = headers.dup
        @bucket_id = bucket_id
        @fetch = fetch
      end

      attr_reader :bucket_id
    end
  end
end
