# frozen_string_literal: true

module Supabase
  # Define base error classes if not already provided by the core supabase gem.
  unless defined?(Supabase::Error)
    class Error < StandardError
      attr_reader :context

      def initialize(message = nil, context: nil)
        @context = context
        super(message)
      end
    end
  end

  unless defined?(Supabase::ApiError)
    class ApiError < Error
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end
  end

  unless defined?(Supabase::NetworkError)
    class NetworkError < Error
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end
  end

  module Storage
    # Base error class for all Storage errors.
    class StorageError < Supabase::Error
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
