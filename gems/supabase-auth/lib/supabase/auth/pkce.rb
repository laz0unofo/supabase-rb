# frozen_string_literal: true

require "securerandom"
require "digest"
require "base64"

module Supabase
  module Auth
    # PKCE (Proof Key for Code Exchange) utilities for secure OAuth flows.
    # Generates code verifiers and challenges per RFC 7636.
    module PKCE
      module_function

      # Generates a 112-character hex code verifier (56 random bytes).
      def generate_code_verifier
        SecureRandom.hex(56)
      end

      # Generates a base64url-encoded SHA-256 code challenge from a verifier.
      def generate_code_challenge(verifier)
        digest = Digest::SHA256.digest(verifier)
        Base64.urlsafe_encode64(digest, padding: false)
      end

      # Returns the code challenge method (always S256).
      def challenge_method
        "s256"
      end
    end
  end
end
