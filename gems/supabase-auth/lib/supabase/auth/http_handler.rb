# frozen_string_literal: true

require "faraday"
require "json"

module Supabase
  module Auth
    # HTTP request handling for the Auth client.
    # Manages Faraday connections, sends standard headers, and raises on errors.
    module HttpHandler
      API_VERSION = "2024-01-01"
      CLIENT_INFO = "supabase-rb/#{VERSION}".freeze

      private

      def request(method, path, body: nil, headers: {}, jwt: nil)
        url = "#{@url}#{path}"
        merged_headers = build_request_headers(headers, jwt)
        response = perform_http(method, url, body, merged_headers)
        classify_and_return(response)
      rescue Faraday::Error => e
        raise ErrorClassifier.classify_exception(e)
      end

      def perform_http(method, url, body, headers)
        connection = build_connection
        connection.run_request(method, url, body ? JSON.generate(body) : nil, headers)
      end

      def build_request_headers(extra_headers, jwt)
        headers = default_headers.merge(@headers)
        headers["Authorization"] = "Bearer #{jwt}" if jwt
        extra_headers.each { |key, val| headers[key.to_s] = val.to_s }
        headers
      end

      def default_headers
        {
          "Content-Type" => "application/json",
          "Accept" => "application/json",
          "X-Supabase-Api-Version" => API_VERSION,
          "X-Client-Info" => CLIENT_INFO
        }
      end

      def classify_and_return(response)
        error = ErrorClassifier.classify_response(response)
        raise error if error

        parse_response_data(response)
      end

      def parse_response_data(response)
        return nil if response.body.nil? || response.body.to_s.strip.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end

      def build_connection
        return @fetch.call if @fetch

        Faraday.new do |conn|
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
