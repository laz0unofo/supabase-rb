# frozen_string_literal: true

require_relative "filter_builder"

module Supabase
  module PostgREST
    # Provides CRUD operation methods (select, insert, update, upsert, delete)
    # for QueryBuilder. Extracted as a module to keep class size manageable.
    module CrudBuilder
      # Performs a SELECT query.
      #
      # @param columns [String] Columns to select (default "*")
      # @param head [Boolean] Use HEAD method (count only, no body)
      # @param count [Symbol, nil] Count algorithm (:exact, :planned, :estimated)
      # @return [FilterBuilder]
      def select(columns = "*", head: false, count: nil)
        build_filter(method: head ? :head : :get) do |url, headers|
          cleaned = columns.gsub(/\s/, "")
          append_query_param(url, "select", cleaned)
          append_count_header(headers, count) if count
        end
      end

      # Performs an INSERT operation.
      #
      # @param values [Hash, Array<Hash>] Row(s) to insert
      # @param count [Symbol, nil] Count algorithm (:exact, :planned, :estimated)
      # @param default_to_null [Boolean] Whether missing columns default to null
      # @return [FilterBuilder]
      def insert(values, count: nil, default_to_null: true)
        build_filter(method: :post, body: values) do |url, headers|
          headers["Content-Type"] = "application/json"
          set_columns_param(url, values)
          append_count_header(headers, count) if count
          append_prefer(headers, "missing=default") unless default_to_null
        end
      end

      # Performs an UPDATE operation.
      #
      # @param values [Hash] Column values to update
      # @param count [Symbol, nil] Count algorithm (:exact, :planned, :estimated)
      # @return [FilterBuilder]
      def update(values, count: nil)
        build_filter(method: :patch, body: values) do |_url, headers|
          headers["Content-Type"] = "application/json"
          append_count_header(headers, count) if count
        end
      end

      # Performs an UPSERT operation.
      #
      # @param values [Hash, Array<Hash>] Row(s) to upsert
      # @param on_conflict [String, nil] Conflict target columns
      # @param ignore_duplicates [Boolean] Ignore duplicate rows instead of merging
      # @param count [Symbol, nil] Count algorithm (:exact, :planned, :estimated)
      # @param default_to_null [Boolean] Whether missing columns default to null
      # @return [FilterBuilder]
      def upsert(values, **options)
        build_filter(method: :post, body: values) do |url, headers|
          headers["Content-Type"] = "application/json"
          set_columns_param(url, values)
          configure_upsert(url, headers, **options)
        end
      end

      # Performs a DELETE operation.
      #
      # @param count [Symbol, nil] Count algorithm (:exact, :planned, :estimated)
      # @return [FilterBuilder]
      def delete(count: nil)
        build_filter(method: :delete) do |_url, headers|
          append_count_header(headers, count) if count
        end
      end

      private

      def build_filter(method:, body: nil)
        new_url = @url.dup
        new_headers = @headers.dup
        yield(new_url, new_headers)
        FilterBuilder.new(
          url: new_url.to_s,
          headers: new_headers,
          schema: @schema,
          method: method,
          body: body,
          fetch: @fetch,
          timeout: @timeout
        )
      end

      def append_query_param(url, key, value)
        existing = url.query
        param = "#{key}=#{value}"
        url.query = existing ? "#{existing}&#{param}" : param
      end

      def append_count_header(headers, count)
        append_prefer(headers, "count=#{count}")
      end

      def append_prefer(headers, value)
        existing = headers["Prefer"]
        headers["Prefer"] = existing ? "#{existing}, #{value}" : value
      end

      def set_columns_param(url, values)
        return unless values.is_a?(Array) && !values.empty?

        columns = values.flat_map(&:keys).uniq.join(",")
        append_query_param(url, "columns", columns)
      end

      def configure_upsert(url, headers, **options)
        on_conflict = options[:on_conflict]
        ignore_duplicates = options.fetch(:ignore_duplicates, false)
        count = options[:count]
        default_to_null = options.fetch(:default_to_null, true)

        resolution = ignore_duplicates ? "resolution=ignore-duplicates" : "resolution=merge-duplicates"
        append_prefer(headers, resolution)
        append_query_param(url, "on_conflict", on_conflict) if on_conflict
        append_count_header(headers, count) if count
        append_prefer(headers, "missing=default") unless default_to_null
      end
    end
  end
end
