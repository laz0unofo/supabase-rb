# frozen_string_literal: true

require "uri"

module Supabase
  # Derives service-specific URLs from the Supabase project URL.
  module UrlBuilder
    private

    def derive_auth_url(base_url)
      "#{base_url}/auth/v1"
    end

    def derive_rest_url(base_url)
      "#{base_url}/rest/v1"
    end

    def derive_realtime_url(base_url)
      uri = URI.parse(base_url)
      scheme = uri.scheme == "https" ? "wss" : "ws"
      "#{scheme}://#{uri.host}#{port_suffix(uri)}/realtime/v1"
    end

    def derive_storage_url(base_url)
      "#{base_url}/storage/v1"
    end

    def derive_functions_url(base_url)
      "#{base_url}/functions/v1"
    end

    def derive_storage_key(base_url)
      host = URI.parse(base_url).host
      first_part = host.split(".").first
      "sb-#{first_part}-auth-token"
    end

    def port_suffix(uri)
      return "" unless uri.port
      return "" if (uri.scheme == "https" && uri.port == 443) || (uri.scheme == "http" && uri.port == 80)

      ":#{uri.port}"
    end
  end
end
