# frozen_string_literal: true

module Supabase
  module Auth
    # Multi-Factor Authentication API.
    # Provides methods for enrolling, challenging, verifying, and managing MFA factors.
    # Accessed via client.mfa.
    class MfaApi
      MFA_METHODS = %w[mfa/totp mfa/phone].freeze

      def initialize(client)
        @client = client
      end

      # Enrolls a new MFA factor (TOTP or Phone).
      # Returns factor with QR code (TOTP) or phone details.
      def enroll(factor_type:, friendly_name: nil, issuer: nil, phone: nil)
        body = { factor_type: factor_type.to_s }
        body[:friendly_name] = friendly_name if friendly_name
        body[:issuer] = issuer if issuer
        body[:phone] = phone if phone

        @client.send(:mfa_request, :post, "/factors", body: body)
      end

      # Creates a challenge for a given factor.
      def challenge(factor_id:)
        @client.send(:mfa_request, :post, "/factors/#{factor_id}/challenge")
      end

      # Verifies a challenge with the provided code.
      # Saves the aal2 session and emits MFA_CHALLENGE_VERIFIED.
      def verify(factor_id:, challenge_id:, code:)
        body = { challenge_id: challenge_id, code: code }
        result = @client.send(:mfa_request, :post, "/factors/#{factor_id}/verify", body: body)
        return result if result[:error]

        @client.send(:handle_mfa_verify, result[:data])
      end

      # Unenrolls (removes) a factor.
      def unenroll(factor_id:)
        @client.send(:mfa_request, :delete, "/factors/#{factor_id}")
      end

      # Convenience method that combines challenge + verify in one call.
      def challenge_and_verify(factor_id:, code:)
        challenge_result = challenge(factor_id: factor_id)
        return challenge_result if challenge_result[:error]

        challenge_id = challenge_result[:data]["id"]
        verify(factor_id: factor_id, challenge_id: challenge_id, code: code)
      end

      # Lists the user's MFA factors, categorized by type.
      def list_factors
        result = @client.get_user
        return result if result[:error]

        factors = extract_factors(result[:data][:user])
        categorize_factors(factors)
      end

      # Returns the current authenticator assurance level from the JWT.
      def get_authenticator_assurance_level # rubocop:disable Naming/AccessorMethodName
        result = @client.get_session
        return { data: nil, error: result[:error] } if result[:error]

        session = result[:data][:session]
        return build_aal_result(nil, nil, []) unless session

        payload = JWT.decode(session.access_token)
        return build_aal_result(nil, nil, []) unless payload

        current_level = parse_aal(payload["aal"])
        amr = payload["amr"] || []
        next_level = compute_next_level(current_level, amr)

        build_aal_result(current_level, next_level, amr)
      end

      private

      def extract_factors(user)
        user&.dig("factors") || []
      end

      def categorize_factors(factors)
        totp = verified_factors_by_type(factors, "totp")
        phone = verified_factors_by_type(factors, "phone")
        { data: { all: factors, totp: totp, phone: phone }, error: nil }
      end

      def verified_factors_by_type(factors, type)
        factors.select { |f| f["factor_type"] == type && f["status"] == "verified" }
      end

      def parse_aal(aal_value)
        return nil unless aal_value

        aal_value.to_sym
      end

      def compute_next_level(current_level, amr)
        has_mfa = amr.any? { |entry| MFA_METHODS.include?(entry["method"]) }
        return current_level if has_mfa

        current_level == :aal1 ? :aal2 : current_level
      end

      def build_aal_result(current_level, next_level, amr)
        {
          data: {
            current_level: current_level,
            next_level: next_level,
            current_authentication_methods: amr
          },
          error: nil
        }
      end
    end
  end
end
