# frozen_string_literal: true

require "base64"
require "json"

module Supabase
  module Auth
    # JWT decoding utility. Decodes JWT payload without signature verification.
    # Used for reading token claims (exp, sub, aal, amr, etc.).
    module JWT
      module_function

      # Decodes a JWT and returns the payload as a Hash.
      # Does NOT verify the signature (this is intentional for client-side token inspection).
      def decode(token)
        parts = token.to_s.split(".")
        return nil unless parts.length == 3

        payload = base64url_decode(parts[1])
        JSON.parse(payload)
      rescue JSON::ParserError, ArgumentError
        nil
      end

      # Decodes a base64url-encoded string (RFC 4648).
      def base64url_decode(str)
        padded = str + ("=" * ((4 - (str.length % 4)) % 4))
        Base64.urlsafe_decode64(padded)
      end
    end
  end
end
