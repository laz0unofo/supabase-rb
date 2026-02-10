# frozen_string_literal: true

module Supabase
  module PostgREST
    # Provides range, text search, and compound filter methods for FilterBuilder.
    # Extracted as a module to keep class size under rubocop ClassLength limit.
    module RangeFilters
      # Range strictly greater than: column=sr.value
      def range_gt(column, value)
        append_filter(column, "sr", value)
      end

      # Range greater than or equal (not extends left of): column=nxl.value
      def range_gte(column, value)
        append_filter(column, "nxl", value)
      end

      # Range strictly less than: column=sl.value
      def range_lt(column, value)
        append_filter(column, "sl", value)
      end

      # Range less than or equal (not extends right of): column=nxr.value
      def range_lte(column, value)
        append_filter(column, "nxr", value)
      end

      # Range adjacent: column=adj.value
      def range_adjacent(column, value)
        append_filter(column, "adj", value)
      end

      # Full-text search filter.
      # @param column [String] Column name
      # @param query [String] Search query
      # @param type [Symbol, nil] Search type (:plain, :phrase, :websearch, nil for default fts)
      # @param config [String, nil] Text search config (e.g., "english")
      def text_search(column, query, type: nil, config: nil)
        operator = text_search_operator(type)
        operator = "#{operator}(#{config})" if config
        append_filter(column, operator, query)
      end

      # Match filter: applies multiple eq filters from a hash.
      # @param query_hash [Hash] Column-value pairs to match
      def match_filter(query_hash)
        query_hash.each { |col, val| append_filter(col, "eq", val) }
        self
      end

      # Negate a filter: column=not.op.value
      def not(column, operator, value)
        append_filter(column, "not.#{operator}", value)
      end

      # OR filter: or=(filter1,filter2,...)
      # @param filters [String] Filter string (e.g., "id.eq.1,name.eq.test")
      # @param referenced_table [String, nil] Foreign table for nested OR
      def or(filters, referenced_table: nil)
        key = referenced_table ? "#{referenced_table}.or" : "or"
        append_query_param(@url, key, "(#{filters})")
        self
      end

      # Generic filter: column=op.value
      def filter(column, operator, value)
        append_filter(column, operator, value)
      end

      private

      def text_search_operator(type)
        case type
        when :plain then "plfts"
        when :phrase then "phfts"
        when :websearch then "wfts"
        else "fts"
        end
      end
    end
  end
end
