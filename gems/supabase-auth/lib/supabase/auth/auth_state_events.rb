# frozen_string_literal: true

module Supabase
  module Auth
    # Auth state change event constants and subscription management.
    # Provides on_auth_state_change for subscribing to auth events.
    module AuthStateEvents
      EVENTS = %i[
        initial_session
        signed_in
        signed_out
        token_refreshed
        user_updated
        password_recovery
        mfa_challenge_verified
      ].freeze

      # Registers a block-based listener for auth state changes.
      # Returns a Subscription with id and unsubscribe method.
      # Fires INITIAL_SESSION once asynchronously with the current session.
      def on_auth_state_change(&callback)
        id = SecureRandom.uuid
        listener = { id: id, callback: callback }
        @listeners << listener

        subscription = Subscription.new(id: id) do
          @listeners.delete_if { |l| l[:id] == id }
        end

        deliver_initial_session(listener)

        subscription
      end

      private

      def deliver_initial_session(listener)
        Thread.new do
          session = load_session
          listener[:callback].call(:initial_session, session)
        rescue StandardError => e
          log_debug("Initial session delivery error: #{e.message}")
        end
      end
    end
  end
end
