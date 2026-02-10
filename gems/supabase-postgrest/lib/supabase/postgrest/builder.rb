# frozen_string_literal: true

require "faraday"
require "json"
require "uri"
require_relative "response_handler"

module Supabase
  module PostgREST
    # Base builder class that carries HTTP method, URL, headers, body, and schema.
    # All query builder classes inherit from this and call #execute to perform the request.
    class Builder
      include ResponseHandler

      attr_reader :url, :headers, :body, :method, :schema

      # @param url [String] Request URL
      # @param options [Hash] Builder options (:headers, :schema, :method, :body, :fetch, :timeout)
      def initialize(url:, **options)
        @url = URI.parse(url)
        @headers = (options[:headers] || {}).dup
        @schema = options[:schema]
        @method = options[:method] || :get
        @body = options[:body]
        @fetch = options[:fetch]
        @timeout = options[:timeout]
        @throw_on_error = false
      end

      # Returns a new builder with throw_on_error enabled.
      # When enabled, PostgrestError is raised instead of returned in the result hash.
      def throw_on_error
        dup_with { |b| b.instance_variable_set(:@throw_on_error, true) }
      end

      # Executes the built request and returns the result hash.
      def execute
        apply_schema_headers
        response = perform_request
        build_result(response)
      rescue Faraday::Error => e
        handle_fetch_error(e)
      end

      private

      def dup_with
        copy = dup
        copy.instance_variable_set(:@url, @url.dup)
        copy.instance_variable_set(:@headers, @headers.dup)
        yield copy if block_given?
        copy
      end

      def apply_schema_headers
        return unless @schema

        if %i[get head].include?(@method)
          @headers["Accept-Profile"] = @schema
        else
          @headers["Content-Profile"] = @schema
        end
      end

      def perform_request
        conn = build_connection
        conn.run_request(@method, @url.to_s, request_body, @headers)
      end

      def request_body
        return nil if @body.nil?

        @body.is_a?(String) ? @body : JSON.generate(@body)
      end

      def build_connection
        return @fetch.call(@timeout) if @fetch

        Faraday.new do |f|
          f.options.timeout = @timeout if @timeout
          f.options.open_timeout = @timeout if @timeout
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
