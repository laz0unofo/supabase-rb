# frozen_string_literal: true

module Supabase
  module Auth
    # Represents an authenticated session with access and refresh tokens.
    # Computes expires_at from expires_in if not provided.
    class Session
      attr_reader :access_token, :refresh_token, :expires_in, :expires_at, :token_type, :user

      def initialize(data)
        @access_token = data["access_token"] || data[:access_token]
        @refresh_token = data["refresh_token"] || data[:refresh_token]
        @expires_in = data["expires_in"] || data[:expires_in]
        @token_type = data["token_type"] || data[:token_type]
        @user = data["user"] || data[:user]
        @expires_at = compute_expires_at(data)
      end

      def expired?
        return false unless @expires_at

        Time.now.to_i >= @expires_at
      end

      def to_h
        {
          "access_token" => @access_token,
          "refresh_token" => @refresh_token,
          "expires_in" => @expires_in,
          "expires_at" => @expires_at,
          "token_type" => @token_type,
          "user" => @user
        }
      end

      private

      def compute_expires_at(data)
        explicit = data["expires_at"] || data[:expires_at]
        return explicit.to_i if explicit

        return Time.now.to_i + @expires_in.to_i if @expires_in

        nil
      end
    end
  end
end
