# frozen_string_literal: true

module Supabase
  # Delegation methods that proxy calls to sub-clients.
  # PostgREST: from, schema, rpc
  # Realtime: channel, get_channels, remove_channel, remove_all_channels
  module Delegation
    def from(relation)
      @postgrest_client.from(relation)
    end

    def schema(name)
      @postgrest_client.schema(name)
    end

    def rpc(function_name, **options)
      @postgrest_client.rpc(function_name, **options)
    end

    def channel(name, config: {})
      @realtime_client.channel(name, config: config)
    end

    # rubocop:disable Naming/AccessorMethodName
    def get_channels
      @realtime_client.get_channels
    end
    # rubocop:enable Naming/AccessorMethodName

    def remove_channel(channel)
      @realtime_client.remove_channel(channel)
    end

    def remove_all_channels
      @realtime_client.remove_all_channels
    end
  end
end
