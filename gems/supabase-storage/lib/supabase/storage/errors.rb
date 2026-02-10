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
    # Mixin module so all Storage errors respond to `is_a?(StorageError)`.
    module StorageError
    end

    # Base error class for Storage errors that don't map to HTTP or network failures.
    class StorageBaseError < Supabase::Error
      include StorageError
    end

    # Raised when the Storage API returns an HTTP error response.
    class StorageApiError < Supabase::ApiError
      include StorageError
    end

    # Raised when an unknown error occurs (network failure, unexpected response).
    class StorageUnknownError < Supabase::NetworkError
      include StorageError
    end
  end
end
