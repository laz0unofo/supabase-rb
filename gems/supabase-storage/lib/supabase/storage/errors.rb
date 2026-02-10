# frozen_string_literal: true

module Supabase
  module Storage
    # Base error class for all Storage errors.
    class StorageError < StandardError
      attr_reader :context

      def initialize(message = nil, context: nil)
        @context = context
        super(message)
      end
    end

    # Raised when the Storage API returns an HTTP error response.
    class StorageApiError < StorageError
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end

    # Raised when an unknown error occurs (network failure, unexpected response).
    class StorageUnknownError < StorageError
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end
  end
end
