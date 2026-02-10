# frozen_string_literal: true

module Supabase
  # Unified base error class for all Supabase SDK errors.
  class Error < StandardError
    attr_reader :context

    def initialize(message = nil, context: nil)
      @context = context
      super(message)
    end
  end

  # Base class for HTTP-level API errors (non-2xx responses).
  class ApiError < Error
    attr_reader :status

    def initialize(message = nil, status: nil, context: nil)
      @status = status
      super(message, context: context)
    end
  end

  # Base class for network/connection failures (wraps Faraday errors).
  class NetworkError < Error
    attr_reader :status

    def initialize(message = nil, status: nil, context: nil)
      @status = status
      super(message, context: context)
    end
  end

  # Legacy alias for backwards compatibility within the SDK.
  SupabaseError = Error

  class AuthNotAvailableError < Error; end
end
