# frozen_string_literal: true

module Supabase
  module PostgREST
    # FilterBuilder is returned by CRUD operations on QueryBuilder.
    # It provides filter/transform chaining (US-006, US-007) and
    # the .select method for mutation results (return=representation).
    class FilterBuilder < Builder
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

      private

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
    end
  end
end
