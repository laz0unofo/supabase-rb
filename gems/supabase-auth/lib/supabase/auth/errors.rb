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

  module Auth
    # Mixin module so all Auth errors respond to `is_a?(AuthError)`.
    module AuthError
    end

    # Base error class for Auth errors that don't map to HTTP or network failures.
    class AuthBaseError < Supabase::Error
      include AuthError
    end

    # Raised when the Auth API returns an HTTP error (4xx with JSON body).
    class AuthApiError < Supabase::ApiError
      include AuthError

      attr_reader :code

      def initialize(message = nil, status: nil, code: nil, context: nil)
        @code = code
        super(message, status: status, context: context)
      end
    end

    # Raised when the Auth API returns a retryable error (502, 503, 504, or network failure).
    class AuthRetryableFetchError < Supabase::NetworkError
      include AuthError
    end

    # Raised when an unknown error occurs (4xx non-JSON or unexpected response).
    class AuthUnknownError < Supabase::ApiError
      include AuthError
    end

    # Raised when a session is required but not available.
    class AuthSessionMissingError < AuthBaseError
    end

    # Raised when the token response is invalid or malformed.
    class AuthInvalidTokenResponseError < AuthBaseError
    end

    # Raised when credentials are invalid.
    class AuthInvalidCredentialsError < AuthBaseError
    end

    # Raised when the password is too weak.
    class AuthWeakPasswordError < AuthApiError
      attr_reader :reasons

      def initialize(message = nil, status: nil, code: nil, reasons: [], context: nil)
        @reasons = reasons
        super(message, status: status, code: code, context: context)
      end
    end

    # Raised when PKCE code exchange fails.
    class AuthPKCEGrantCodeExchangeError < AuthBaseError
    end

    # Type guard methods for error classification.
    module ErrorGuards
      def auth_error?(error)
        error.is_a?(AuthError)
      end

      def auth_api_error?(error)
        error.is_a?(AuthApiError)
      end

      def auth_session_missing_error?(error)
        error.is_a?(AuthSessionMissingError)
      end

      def auth_retryable_fetch_error?(error)
        error.is_a?(AuthRetryableFetchError)
      end
    end
  end
end
