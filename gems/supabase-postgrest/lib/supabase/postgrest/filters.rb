# frozen_string_literal: true

module Supabase
  module PostgREST
    # Provides comparison filter methods for FilterBuilder.
    # Extracted as a module to keep class size under rubocop ClassLength limit.
    module Filters
      # Equals filter: column=eq.value
      def eq(column, value)
        append_filter(column, "eq", value)
      end

      # Not equals filter: column=neq.value
      def neq(column, value)
        append_filter(column, "neq", value)
      end

      # Greater than filter: column=gt.value
      def gt(column, value)
        append_filter(column, "gt", value)
      end

      # Greater than or equal filter: column=gte.value
      def gte(column, value)
        append_filter(column, "gte", value)
      end

      # Less than filter: column=lt.value
      def lt(column, value)
        append_filter(column, "lt", value)
      end

      # Less than or equal filter: column=lte.value
      def lte(column, value)
        append_filter(column, "lte", value)
      end

      # Is filter for null/true/false: column=is.value
      def is(column, value)
        append_filter(column, "is", value)
      end

      # Is distinct from filter: column=isdistinct.value
      def is_distinct(column, value) # rubocop:disable Naming/PredicatePrefix
        append_filter(column, "isdistinct", value)
      end

      # LIKE filter: column=like.pattern
      def like(column, pattern)
        append_filter(column, "like", pattern)
      end

      # ILIKE filter: column=ilike.pattern
      def ilike(column, pattern)
        append_filter(column, "ilike", pattern)
      end

      # LIKE ALL filter: column=like(all).{patterns}
      def like_all_of(column, patterns)
        append_filter(column, "like(all)", "{#{patterns.join(",")}}")
      end

      # LIKE ANY filter: column=like(any).{patterns}
      def like_any_of(column, patterns)
        append_filter(column, "like(any)", "{#{patterns.join(",")}}")
      end

      # ILIKE ALL filter: column=ilike(all).{patterns}
      def ilike_all_of(column, patterns)
        append_filter(column, "ilike(all)", "{#{patterns.join(",")}}")
      end

      # ILIKE ANY filter: column=ilike(any).{patterns}
      def ilike_any_of(column, patterns)
        append_filter(column, "ilike(any)", "{#{patterns.join(",")}}")
      end

      # Regex match filter: column=match.pattern
      def match(column, pattern)
        append_filter(column, "match", pattern)
      end

      # Case-insensitive regex match filter: column=imatch.pattern
      def imatch(column, pattern)
        append_filter(column, "imatch", pattern)
      end

      # IN filter: column=in.(quoted_values)
      def in(column, values)
        quoted = values.map { |v| quote_filter_value(v) }
        append_filter(column, "in", "(#{quoted.join(",")})")
      end

      # Contains filter (array/json): column=cs.value
      def contains(column, value)
        append_filter(column, "cs", format_containment(value))
      end

      # Contained by filter: column=cd.value
      def contained_by(column, value)
        append_filter(column, "cd", format_containment(value))
      end

      # Overlaps filter (array): column=ov.value
      def overlaps(column, value)
        append_filter(column, "ov", format_containment(value))
      end
    end
  end
end
