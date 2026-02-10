# frozen_string_literal: true

module Supabase
  module Auth
    # Classifies HTTP responses and exceptions into the appropriate Auth error types.
    # 4xx JSON -> AuthApiError, 4xx non-JSON -> AuthUnknownError,
    # 502/503/504 -> AuthRetryableFetchError, network failure -> AuthRetryableFetchError (status 0),
    # weak_password code -> AuthWeakPasswordError
    module ErrorClassifier
      RETRYABLE_STATUSES = [502, 503, 504].freeze

      module_function

      def classify_response(response)
        status = response.status

        return classify_retryable(status, response) if RETRYABLE_STATUSES.include?(status)
        return nil if status >= 200 && status < 300

        classify_error_response(status, response)
      end

      def classify_exception(exception)
        AuthRetryableFetchError.new(exception.message, status: 0, context: exception)
      end

      def classify_error_response(status, response)
        body = parse_json_body(response.body)
        return classify_json_error(status, body) if body

        AuthUnknownError.new(response.body.to_s, status: status)
      end

      def classify_json_error(status, body)
        code = body["error_code"] || body["code"]
        message = body["msg"] || body["message"] || body["error_description"] || body["error"]
        return build_weak_password_error(status, code, message, body) if code == "weak_password"

        AuthApiError.new(message, status: status, code: code)
      end

      def build_weak_password_error(status, code, message, body)
        reasons = body["weak_password"]&.fetch("reasons", []) || []
        AuthWeakPasswordError.new(message, status: status, code: code, reasons: reasons)
      end

      def classify_retryable(status, response)
        AuthRetryableFetchError.new(response.body.to_s, status: status)
      end

      def parse_json_body(body)
        return nil if body.nil? || body.to_s.strip.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
