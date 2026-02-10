# frozen_string_literal: true

module Supabase
  module Auth
    # Base error class for all Auth errors.
    class AuthError < StandardError
      attr_reader :context

      def initialize(message = nil, context: nil)
        @context = context
        super(message)
      end
    end

    # Raised when the Auth API returns an HTTP error (4xx with JSON body).
    class AuthApiError < AuthError
      attr_reader :status, :code

      def initialize(message = nil, status: nil, code: nil, context: nil)
        @status = status
        @code = code
        super(message, context: context)
      end
    end

    # Raised when the Auth API returns a retryable error (502, 503, 504, or network failure).
    class AuthRetryableFetchError < AuthError
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end

    # Raised when an unknown error occurs (4xx non-JSON or unexpected response).
    class AuthUnknownError < AuthError
      attr_reader :status

      def initialize(message = nil, status: nil, context: nil)
        @status = status
        super(message, context: context)
      end
    end

    # Raised when a session is required but not available.
    class AuthSessionMissingError < AuthError
    end

    # Raised when the token response is invalid or malformed.
    class AuthInvalidTokenResponseError < AuthError
    end

    # Raised when credentials are invalid.
    class AuthInvalidCredentialsError < AuthError
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
    class AuthPKCEGrantCodeExchangeError < AuthError
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
