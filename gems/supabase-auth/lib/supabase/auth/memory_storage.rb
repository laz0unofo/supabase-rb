# frozen_string_literal: true

module Supabase
  module Auth
    # In-memory storage adapter implementing the StorageAdapter interface.
    # Used as the default storage when no external storage is provided.
    class MemoryStorage
      def initialize
        @store = {}
      end

      def get_item(key)
        @store[key]
      end

      def set_item(key, value)
        @store[key] = value
      end

      def remove_item(key)
        @store.delete(key)
      end
    end
  end
end
