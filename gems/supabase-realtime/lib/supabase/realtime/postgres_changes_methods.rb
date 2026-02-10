# frozen_string_literal: true

module Supabase
  module Realtime
    # PostgreSQL CDC listener registration for RealtimeChannel.
    module PostgresChangesMethods
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
