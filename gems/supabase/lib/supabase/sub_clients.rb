# frozen_string_literal: true

module Supabase
  # Sub-client accessor methods for the top-level Supabase::Client.
  # Provides lazy-initialized accessors for auth, storage, functions,
  # and shared postgrest/realtime clients.
  module SubClients
    # Returns the Auth client. Raises AuthNotAvailableError in third-party auth mode.
    def auth
      if @access_token_callback
        raise AuthNotAvailableError, "Auth client is not available when using third-party auth (access_token)"
      end

      @auth_client
    end

    # Returns the shared Storage client.
    def storage
      @storage_client
    end

    # Creates a new Functions client on each access (picks up latest headers).
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
