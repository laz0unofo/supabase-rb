# frozen_string_literal: true

module Supabase
  module Realtime
    # PostgreSQL CDC listener registration for RealtimeChannel.
    module PostgresChangesMethods
      # Registers a callback for PostgreSQL change data capture events.
      #
      # @param event [Symbol] the change event type (:all, :*, :insert, :update, :delete)
      # @param schema [String] the database schema to listen on (default: "public")
      # @param table [String, nil] the table name to filter (nil for all tables)
      # @param filter [String, nil] a PostgREST-style filter expression (e.g. "id=eq.1")
      # @yield [payload] called when a matching database change occurs
      # @yieldparam payload [Hash] the change event payload with record data
      # @return [self]
      def on_postgres_changes(event:, schema: "public", table: nil, filter: nil, &callback)
        binding_config = build_postgres_binding(event, schema, table, filter)
        @bindings << { type: :postgres_changes, callback: callback, **binding_config }
        self
      end

      private

      def build_postgres_binding(event, schema, table, filter)
        config = { event: normalize_pg_event(event), schema: schema }
        config[:table] = table if table
        config[:filter] = filter if filter
        config
      end

      def normalize_pg_event(event)
        case event
        when :all, :* then "*"
        when :insert then "INSERT"
        when :update then "UPDATE"
        when :delete then "DELETE"
        else event.to_s.upcase
        end
      end
    end
  end
end
