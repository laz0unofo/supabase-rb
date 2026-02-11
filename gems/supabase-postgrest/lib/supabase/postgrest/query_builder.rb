# frozen_string_literal: true

require_relative "crud_builder"

module Supabase
  module PostgREST
    # QueryBuilder is scoped to a specific table/view.
    # Returned by Client#from, it provides entry points for CRUD operations
    # (select, insert, update, upsert, delete).
    class QueryBuilder < Builder
      include CrudBuilder

      attr_reader :relation

      # @param url [String] Base PostgREST URL (e.g., "http://localhost:3000/rest/v1")
      # @param relation [String] Table or view name
      # @param options [Hash] Additional options (:headers, :schema, :fetch, :timeout)
      def initialize(url:, relation:, **)
        @relation = relation
        super(url: "#{url}/#{relation}", **)
      end
    end
  end
end
