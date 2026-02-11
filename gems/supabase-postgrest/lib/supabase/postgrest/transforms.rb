# frozen_string_literal: true

module Supabase
  module PostgREST
    # Provides transform methods for FilterBuilder: ordering, pagination,
    # result shaping (single/csv/geojson), explain, rollback, and max_affected.
    # Extracted as a module to keep class size under rubocop ClassLength limit.
    module Transforms
      # Orders the result by a column.
      # Supports multiple calls (appends order params).
      #
      # @param column [String, Symbol] Column to order by
      # @param ascending [Boolean] Sort ascending (default true)
      # @param nulls_first [Boolean, nil] Nulls first (true), nulls last (false), or default (nil)
      # @param referenced_table [String, nil] Foreign table for ordering
      # @return [self]
      def order(column, ascending: true, nulls_first: nil, referenced_table: nil)
        direction = ascending ? "asc" : "desc"
        value = "#{column}.#{direction}"
        value += ".nullsfirst" if nulls_first == true
        value += ".nullslast" if nulls_first == false
        key = referenced_table ? "#{referenced_table}.order" : "order"
        append_order_param(key, value)
        self
      end

      # Limits the number of rows returned.
      #
      # @param count [Integer] Maximum rows to return
      # @param referenced_table [String, nil] Foreign table for limiting
      # @return [self]
      def limit(count, referenced_table: nil)
        key = referenced_table ? "#{referenced_table}.limit" : "limit"
        append_query_param(@url, key, count.to_s)
        self
      end

      # Sets the range of rows to return (0-based inclusive).
      #
      # @param from [Integer] Start index (inclusive)
      # @param to [Integer] End index (inclusive)
      # @param referenced_table [String, nil] Foreign table for range
      # @return [self]
      def range(from, to, referenced_table: nil)
        offset_key = referenced_table ? "#{referenced_table}.offset" : "offset"
        limit_key = referenced_table ? "#{referenced_table}.limit" : "limit"
        append_query_param(@url, offset_key, from.to_s)
        append_query_param(@url, limit_key, (to - from + 1).to_s)
        self
      end

      # Requests a single object response. Sets Accept header to
      # application/vnd.pgrst.object+json. PostgREST will error if != 1 row.
      #
      # @return [self]
      def single
        @headers["Accept"] = "application/vnd.pgrst.object+json"
        self
      end

      # Requests a single object or nil. For GET requests, unwraps arrays
      # and synthesizes PGRST116 error on >1 row.
      #
      # @return [self]
      def maybe_single
        @headers["Accept"] = "application/vnd.pgrst.object+json"
        @maybe_single = true
        self
      end

      # Sets Accept header to text/csv for CSV response format.
      #
      # @return [self]
      def csv
        @headers["Accept"] = "text/csv"
        self
      end

      # Sets Accept header to application/geo+json for GeoJSON response format.
      #
      # @return [self]
      def geojson
        @headers["Accept"] = "application/geo+json"
        self
      end

      # Sets the explain plan options for query analysis.
      #
      # @param analyze [Boolean] Include actual run times
      # @param verbose [Boolean] Include verbose output
      # @param settings [Boolean] Include settings
      # @param buffers [Boolean] Include buffer usage
      # @param wal [Boolean] Include WAL usage
      # @param format [Symbol] Output format (:text or :json)
      # @return [self]
      def explain(**)
        build_explain_header(**)
        self
      end

      # Appends Prefer: tx=rollback to roll back the transaction.
      #
      # @return [self]
      def rollback
        append_prefer_self("tx=rollback")
        self
      end

      # Sets max affected rows with strict handling.
      #
      # @param value [Integer] Maximum number of affected rows
      # @return [self]
      def max_affected(value)
        append_prefer_self("handling=strict,max-affected=#{value}")
        self
      end

      private

      def append_order_param(key, value)
        existing = @url.query
        # Append to existing order param if present
        if existing&.include?("#{key}=")
          @url.query = existing.gsub(/#{Regexp.escape(key)}=([^&]*)/) do
            "#{key}=#{::Regexp.last_match(1)},#{value}"
          end
        else
          append_query_param(@url, key, value)
        end
      end

      def build_explain_header(**)
        parts = collect_explain_parts(**)
        header_value = "for=\"explain\""
        header_value += "|#{parts.join("|")}" unless parts.empty?
        existing = @headers["Accept"]
        @headers["Accept"] = existing ? "#{existing}; #{header_value}" : header_value
      end

      def collect_explain_parts(**options)
        flags = %i[analyze verbose settings buffers wal]
        parts = flags.select { |flag| options[flag] }.map(&:to_s)
        format = options.fetch(:format, :text)
        parts << "format=#{format}" if format != :text
        parts
      end

      def append_prefer_self(value)
        existing = @headers["Prefer"]
        @headers["Prefer"] = existing ? "#{existing}, #{value}" : value
      end
    end
  end
end
