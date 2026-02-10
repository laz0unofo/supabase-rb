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

  module Functions
    # Base error class for all Functions errors.
    class FunctionsError < Supabase::Error
    end

    # Raised when a network or fetch-level error occurs (e.g., connection refused, DNS failure).
    class FunctionsFetchError < FunctionsError
    end

    # Raised when the relay returns an error (x-relay-error header present).
    class FunctionsRelayError < FunctionsError
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end

    # Raised when the function returns a non-2xx HTTP status code.
    class FunctionsHttpError < FunctionsError
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end
  end
end
