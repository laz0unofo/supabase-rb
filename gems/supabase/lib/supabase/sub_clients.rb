# frozen_string_literal: true

module Supabase
  # Sub-client accessor methods for the top-level Supabase::Client.
  # Provides lazy-initialized accessors for auth, storage, functions,
  # and shared postgrest/realtime clients.
  module SubClients
    # Returns the Auth client for user authentication operations.
    #
    # @return [Supabase::Auth::Client] the auth client instance
    # @raise [AuthNotAvailableError] when using third-party auth via :access_token
    def auth
      if @access_token_callback
        raise AuthNotAvailableError, "Auth client is not available when using third-party auth (access_token)"
      end

      @auth_client
    end

    # Returns the Storage client for file upload and management.
    #
    # @return [Supabase::Storage::Client] the storage client instance
    def storage
      @storage_client
    end

    # Creates a new Functions client for invoking Edge Functions.
    # A fresh instance is returned on each call to pick up the latest auth headers.
    #
    # @return [Supabase::Functions::Client] a new functions client instance
    def functions
      Functions::Client.new(
        url: @functions_url,
        headers: build_current_headers
      )
    end

    private

    def init_auth_client(auth_opts)
      @auth_client = Auth::Client.new(
        url: @auth_url,
        headers: @global_headers.dup,
        **auth_opts
      )
    end

    def init_postgrest_client(db_opts)
      @postgrest_client = PostgREST::Client.new(
        url: @rest_url,
        headers: @global_headers.dup,
        schema: db_opts[:schema],
        fetch: @custom_fetch
      )
    end

    def init_realtime_client(realtime_opts)
      params = { apikey: @api_key }.merge(realtime_opts.fetch(:params, {}))
      @realtime_client = Realtime::Client.new(
        @realtime_url,
        params: params,
        **realtime_opts.except(:params)
      )
    end

    def init_storage_client
      @storage_client = Storage::Client.new(
        url: @storage_url,
        headers: @global_headers.dup,
        fetch: @custom_fetch
      )
    end

    def build_current_headers
      headers = @global_headers.dup
      token = resolve_current_token
      headers["Authorization"] = "Bearer #{token}" if token
      headers
    end
  end
end
