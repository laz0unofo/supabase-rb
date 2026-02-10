# frozen_string_literal: true

module Supabase
  # Delegation methods that proxy calls to sub-clients.
  # PostgREST: from, schema, rpc
  # Realtime: channel, get_channels, remove_channel, remove_all_channels
  module Delegation
    # Creates a query builder for the given table or view.
    #
    # @param relation [String] the table or view name to query
    # @return [Supabase::PostgREST::QueryBuilder] a query builder for the relation
    def from(relation)
      @postgrest_client.from(relation)
    end

    # Returns a PostgREST client scoped to the given database schema.
    #
    # @param name [String] the database schema name
    # @return [Supabase::PostgREST::Client] a client scoped to the schema
    def schema(name)
      @postgrest_client.schema(name)
    end

    # Invokes a PostgreSQL stored procedure or function via PostgREST.
    #
    # @param function_name [String] the name of the database function to call
    # @param options [Hash] additional options passed to the RPC call (e.g., args, count)
    # @return [Hash] the RPC response as { data:, error: }
    def rpc(function_name, **options)
      @postgrest_client.rpc(function_name, **options)
    end

    # Creates or retrieves a Realtime channel for subscribing to database changes.
    #
    # @param name [String] the channel topic name
    # @param config [Hash] optional channel configuration
    # @return [Supabase::Realtime::RealtimeChannel] the channel instance
    def channel(name, config: {})
      @realtime_client.channel(name, config: config)
    end

    # Returns all currently subscribed Realtime channels.
    #
    # @return [Array<Supabase::Realtime::RealtimeChannel>] list of active channels
    # rubocop:disable Naming/AccessorMethodName
    def get_channels
      @realtime_client.get_channels
    end
    # rubocop:enable Naming/AccessorMethodName

    # Unsubscribes and removes a specific Realtime channel.
    #
    # @param channel [Supabase::Realtime::RealtimeChannel] the channel to remove
    # @return [void]
    def remove_channel(channel)
      @realtime_client.remove_channel(channel)
    end

    # Unsubscribes and removes all Realtime channels.
    #
    # @return [void]
    def remove_all_channels
      @realtime_client.remove_all_channels
    end
  end
end
