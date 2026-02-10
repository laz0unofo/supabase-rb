# frozen_string_literal: true

require "securerandom"

module Supabase
  module Auth
    # Represents a subscription to auth state changes.
    # Returned by on_auth_state_change and provides an unsubscribe method.
    class Subscription
      attr_reader :id

      def initialize(id:, &unsubscribe)
        @id = id
        @unsubscribe_callback = unsubscribe
      end

      def unsubscribe
        @unsubscribe_callback&.call
      end
    end
  end
end
