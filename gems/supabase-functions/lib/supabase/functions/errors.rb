# frozen_string_literal: true

module Supabase
  module Functions
    # Base error class for all Functions errors.
    class FunctionsError < StandardError
      attr_reader :context

      def initialize(message = nil, context: nil)
        @context = context
        super(message)
      end
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
