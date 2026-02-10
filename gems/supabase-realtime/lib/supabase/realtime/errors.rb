# frozen_string_literal: true

module Supabase
  module Realtime
    class RealtimeError < StandardError
      attr_reader :context

      def initialize(message = nil, context: nil)
        @context = context
        super(message)
      end
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
