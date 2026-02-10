# frozen_string_literal: true

require "faraday"
require "json"

module Supabase
  module PostgREST
    # Main PostgREST client. Provides access to tables via #from, schema switching
    # via #schema, and remote procedure calls via #rpc.
    class Client
      # @param url [String] Base URL for the PostgREST service
      # @param headers [Hash] Default headers sent with every request
      # @param schema [String, nil] Default PostgreSQL schema
      # @param fetch [Proc, nil] Optional custom Faraday connection factory
      # @param timeout [Integer, nil] Default timeout in seconds
      def initialize(url:, headers: {}, schema: nil, fetch: nil, timeout: nil)
        @url = url.to_s.chomp("/")
        @headers = headers.dup.freeze
        @schema = schema
        @fetch = fetch
        @timeout = timeout
      end

      # Returns a QueryBuilder scoped to the given table or view.
      # Each call returns an independent builder (immutable - cloned URL/headers).
      #
      # @param relation [String] Table or view name
      # @return [QueryBuilder]
      def from(relation)
        QueryBuilder.new(
          url: @url,
          relation: relation,
          headers: @headers.dup,
          schema: @schema,
          fetch: @fetch,
          timeout: @timeout
        )
      end

      # Returns a new Client targeting a different PostgreSQL schema.
      #
      # @param name [String] Schema name
      # @return [Client]
      def schema(name)
        self.class.new(
          url: @url,
          headers: @headers.dup,
          schema: name,
          fetch: @fetch,
          timeout: @timeout
        )
      end

      # Calls a PostgREST remote procedure (function).
      #
      # @param function_name [String] Function name
      # @param args [Hash] Arguments to pass to the function
      # @param head [Boolean] Use HEAD method (returns no body)
      # @param get [Boolean] Use GET method (pass args as query params)
      # @param count [Symbol, nil] Count algorithm (:exact, :planned, :estimated)
      # @return [Response] on success
      # @raise [PostgrestError] on HTTP error or network failure
      def rpc(function_name, args: {}, head: false, get: false, count: nil)
        builder = build_rpc_builder(function_name, args, head: head, get: get, count: count)
        builder.execute
      end

      private

      def build_rpc_builder(function_name, args, head:, get:, count:)
        method = determine_rpc_method(head, get)
        url = build_rpc_url(function_name, args, get: get)
        headers = build_rpc_headers(method, count)
        body = get || head ? nil : args

        Builder.new(
          url: url,
          headers: headers,
          schema: @schema,
          method: method,
          body: body,
          fetch: @fetch,
          timeout: @timeout
        )
      end

      def determine_rpc_method(head, get)
        return :head if head
        return :get if get

        :post
      end

      def build_rpc_url(function_name, args, get:)
        base = "#{@url}/rpc/#{function_name}"
        return base unless get

        params = args.map { |k, v| "#{k}=#{v}" }.join("&")
        params.empty? ? base : "#{base}?#{params}"
      end

      def build_rpc_headers(method, count)
        hdrs = @headers.dup
        hdrs["Content-Type"] = "application/json" unless %i[get head].include?(method)
        if count
          prefer = hdrs["Prefer"]
          count_pref = "count=#{count}"
          hdrs["Prefer"] = prefer ? "#{prefer}, #{count_pref}" : count_pref
        end
        hdrs
      end
    end
  end
end
