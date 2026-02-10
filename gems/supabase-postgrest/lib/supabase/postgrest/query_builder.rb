# frozen_string_literal: true

module Supabase
  module PostgREST
    # QueryBuilder is scoped to a specific table/view.
    # Returned by Client#from, it provides entry points for CRUD operations
    # (select, insert, update, upsert, delete) which are implemented in US-005.
    class QueryBuilder < Builder
      attr_reader :relation

      # @param url [String] Base PostgREST URL (e.g., "http://localhost:3000/rest/v1")
      # @param relation [String] Table or view name
      # @param options [Hash] Additional options (:headers, :schema, :fetch, :timeout)
      def initialize(url:, relation:, **options)
        @relation = relation
        super(url: "#{url}/#{relation}", **options)
      end
    end
  end
end
