# frozen_string_literal: true

module Supabase
  module Realtime
    # Manages presence state for a RealtimeChannel.
    # Tracks joins, leaves, and synchronization of presence information.
    class Presence
      attr_reader :state

      def initialize
        @state = {}
        @join_callbacks = []
        @leave_callbacks = []
        @sync_callbacks = []
      end

      def on_join(&callback)
        @join_callbacks << callback
      end

      def on_leave(&callback)
        @leave_callbacks << callback
      end

      def on_sync(&callback)
        @sync_callbacks << callback
      end

      def sync(new_state, joins, leaves)
        @state = new_state
        notify_joins(joins) unless joins.empty?
        notify_leaves(leaves) unless leaves.empty?
        notify_sync
      end

      def sync_diff(joins, leaves)
        apply_joins(joins)
        apply_leaves(leaves)
        notify_joins(joins) unless joins.empty?
        notify_leaves(leaves) unless leaves.empty?
        notify_sync
      end

      private

      def apply_joins(joins)
        joins.each do |key, meta|
          @state[key] = meta
        end
      end

      def apply_leaves(leaves)
        leaves.each_key do |key|
          @state.delete(key)
        end
      end

      def notify_joins(joins)
        @join_callbacks.each { |cb| safe_call(cb, joins) }
      end

      def notify_leaves(leaves)
        @leave_callbacks.each { |cb| safe_call(cb, leaves) }
      end

      def notify_sync
        @sync_callbacks.each { |cb| safe_call(cb, @state) }
      end

      def safe_call(callback, payload)
        callback.call(payload)
      rescue StandardError
        nil
      end
    end
  end
end
