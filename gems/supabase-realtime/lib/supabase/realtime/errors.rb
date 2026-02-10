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

  module Realtime
    class RealtimeError < Supabase::Error
    end

    class RealtimeConnectionError < RealtimeError
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end

    class RealtimeSubscriptionError < RealtimeError; end

    class RealtimeApiError < RealtimeError
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end
  end
end
