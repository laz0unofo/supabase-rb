# frozen_string_literal: true

require_relative "filters"
require_relative "range_filters"
require_relative "transforms"

module Supabase
  module PostgREST
    # FilterBuilder is returned by CRUD operations on QueryBuilder.
    # It provides filter/transform chaining and the .select method
    # for mutation results (return=representation).
    class FilterBuilder < Builder
      include Filters
      include RangeFilters
      include Transforms

      # Adds a select clause to a mutation result (INSERT/UPDATE/UPSERT/DELETE).
      # Sets Prefer: return=representation and adds ?select= query param.
      #
      # @param columns [String] Columns to return (default "*")
      # @return [FilterBuilder]
      def select(columns = "*")
        dup_with do |builder|
          cleaned = columns.gsub(/\s/, "")
          url = builder.instance_variable_get(:@url)
          append_query_param(url, "select", cleaned)
          append_prefer(builder, "return=representation")
        end
      end

      # Executes the built request. Handles maybe_single post-processing.
      def execute
        result = super
        return result unless @maybe_single

        handle_maybe_single(result)
      end

      private

      def handle_maybe_single(result)
        return result if result[:error]

        data = result[:data]
        if data.is_a?(Array)
          if data.length > 1
            error = PostgrestError.new(
              "JSON object requested, multiple (or no) rows returned",
              details: "Results contain #{data.length} rows",
              code: "PGRST116"
            )
            raise error if @throw_on_error

            return result.merge(data: nil, error: error)
          end
          return result.merge(data: data.first)
        end
        result
      end

      def append_filter(column, operator, value)
        append_query_param(@url, column.to_s, "#{operator}.#{value}")
        self
      end

      def append_query_param(url, key, value)
        existing = url.query
        param = "#{key}=#{value}"
        url.query = existing ? "#{existing}&#{param}" : param
      end

      def append_prefer(builder, value)
        headers = builder.instance_variable_get(:@headers)
        existing = headers["Prefer"]
        headers["Prefer"] = existing ? "#{existing}, #{value}" : value
      end

      def quote_filter_value(value)
        str = value.to_s
        if str.match?(/[,()"]/)
          "\"#{str.gsub('"', '\\"')}\""
        else
          str
        end
      end

      def format_containment(value)
        case value
        when Array then "{#{value.join(",")}}"
        when Hash then JSON.generate(value)
        else value.to_s
        end
      end
    end
  end
end
