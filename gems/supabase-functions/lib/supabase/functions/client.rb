# frozen_string_literal: true

require "faraday"
require "json"
require "uri"
require_relative "response_handler"

module Supabase
  module Functions
    # Client for invoking Supabase Edge Functions.
    #
    # Supports automatic body serialization, response parsing, error handling,
    # region routing, and multiple HTTP methods.
    class Client
      include ResponseHandler

      VALID_METHODS = %i[post get put patch delete].freeze

      # @param url [String] Base URL for the Functions service
      # @param headers [Hash] Default headers sent with every request
      # @param region [Symbol] Default region for function invocation (:any for no region routing)
      # @param fetch [Proc, nil] Optional custom Faraday connection factory
      def initialize(url:, headers: {}, region: :any, fetch: nil)
        @url = url.to_s.chomp("/")
        @headers = headers.dup.freeze
        @region = region
        @fetch = fetch
        @auth_token = nil
      end

      # Sets the Authorization bearer token for subsequent requests.
      # Named set_auth to match the Supabase client API convention.
      def set_auth(token) # rubocop:disable Naming/AccessorMethodName
        @auth_token = token
      end

      # Invokes a Supabase Edge Function.
      #
      # @param function_name [String] Name of the function to invoke
      # @param options [Hash] Invocation options
      # @option options [Object] :body Request body (auto-serialized)
      # @option options [Hash] :headers Per-request headers (highest precedence)
      # @option options [Symbol] :method HTTP method (:post, :get, :put, :patch, :delete)
      # @option options [Symbol] :region Region override for this request
      # @option options [Integer] :timeout Request timeout in seconds
      # @return [Hash] { data:, error: } result hash
      def invoke(function_name, **options)
        method = (options[:method] || :post).to_sym
        return invalid_method_error(method) unless VALID_METHODS.include?(method)

        effective_region = options[:region] || @region
        request = build_request(function_name, effective_region, options)
        response = perform_request(method, request[:url], request[:body], request[:headers], options[:timeout])
        process_response(response)
      rescue Faraday::Error, IOError => e
        { data: nil, error: FunctionsFetchError.new(e.message, context: e) }
      end

      private

      def invalid_method_error(method)
        { data: nil, error: FunctionsFetchError.new("Invalid HTTP method: #{method}") }
      end

      def build_request(function_name, region, options)
        {
          url: build_url(function_name, region),
          headers: build_headers(options[:body], options[:headers] || {}, region),
          body: serialize_body(options[:body])
        }
      end

      def build_url(function_name, region)
        url = "#{@url}/#{function_name}"
        return url if region.nil? || region == :any

        separator = URI.parse(url).query ? "&" : "?"
        "#{url}#{separator}forceFunctionRegion=#{region}"
      end

      def build_headers(body, invoke_headers, region)
        merged = auto_detect_headers(body)
        apply_client_headers(merged)
        apply_region_header(merged, region)
        invoke_headers.each { |k, v| merged[k.to_s] = v.to_s }
        merged
      end

      def auto_detect_headers(body)
        ct = detect_content_type(body)
        ct ? { "Content-Type" => ct } : {}
      end

      def apply_client_headers(merged)
        @headers.each { |k, v| merged[k.to_s] = v.to_s }
        merged["Authorization"] = "Bearer #{@auth_token}" if @auth_token
      end

      def apply_region_header(merged, region)
        merged["x-region"] = region.to_s if region && region != :any
      end

      def detect_content_type(body)
        case body
        when nil then nil
        when String then "text/plain"
        when Hash, Array then "application/json"
        when IO, StringIO then "application/octet-stream"
        end
      end

      def serialize_body(body)
        case body
        when nil then nil
        when Hash, Array then JSON.generate(body)
        when IO, StringIO then body.read
        else body.to_s
        end
      end

      def perform_request(method, url, body, headers, timeout)
        build_connection(timeout).run_request(method, url, body, headers)
      end

      def build_connection(timeout)
        return @fetch.call(timeout) if @fetch

        Faraday.new do |f|
          f.options.timeout = timeout if timeout
          f.options.open_timeout = timeout if timeout
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
