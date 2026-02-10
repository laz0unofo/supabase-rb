# frozen_string_literal: true

require "uri"

module Supabase
  # Top-level orchestrator client that composes all Supabase service clients.
  # Provides a single entry point with shared authentication and configuration.
  class Client
    include UrlBuilder
    include SubClients
    include Delegation
    include AuthTokenManager

    CLIENT_INFO = "supabase-rb/#{VERSION}".freeze

    def initialize(url, key, **options)
      validate_url!(url)
      validate_key!(key)
      @api_key = key
      @access_token_callback = options[:access_token]
      @custom_fetch = options.dig(:global, :fetch)
      configure_urls(url)
      configure_headers(key, options)
      init_sub_clients(options)
      setup_auth_integration
    end

    private

    def validate_url!(url)
      raise ArgumentError, "supabaseUrl is required" if url.nil? || url.to_s.strip.empty?

      uri = URI.parse(url.to_s)
      raise ArgumentError, "supabaseUrl must be a valid URL" unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
    rescue URI::InvalidURIError
      raise ArgumentError, "supabaseUrl must be a valid URL"
    end

    def validate_key!(key)
      raise ArgumentError, "supabaseKey is required" if key.nil? || key.to_s.strip.empty?
    end

    def configure_urls(url)
      @base_url = url.to_s.chomp("/")
      @auth_url = derive_auth_url(@base_url)
      @rest_url = derive_rest_url(@base_url)
      @realtime_url = derive_realtime_url(@base_url)
      @storage_url = derive_storage_url(@base_url)
      @functions_url = derive_functions_url(@base_url)
    end

    def configure_headers(key, options)
      global_headers = options.dig(:global, :headers) || {}
      @global_headers = {
        "apikey" => key,
        "Authorization" => "Bearer #{key}",
        "X-Client-Info" => CLIENT_INFO
      }.merge(global_headers)
    end

    def init_sub_clients(options)
      auth_opts = build_auth_opts(options)
      init_auth_client(auth_opts) unless @access_token_callback
      init_postgrest_client(options.fetch(:db, {}))
      init_realtime_client(options.fetch(:realtime, {}))
      init_storage_client
    end

    def build_auth_opts(options)
      auth_config = options.fetch(:auth, {})
      storage_key = derive_storage_key(@base_url)
      defaults = { storage_key: storage_key, auto_refresh_token: true, persist_session: true, flow_type: :implicit }
      defaults.merge(auth_config)
    end
  end
end
