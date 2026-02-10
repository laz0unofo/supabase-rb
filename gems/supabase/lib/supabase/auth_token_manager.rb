# frozen_string_literal: true

module Supabase
  # Manages authentication token resolution, propagation, and
  # auth event listening for the top-level Supabase::Client.
  module AuthTokenManager
    TOKEN_EVENTS = %i[signed_in token_refreshed].freeze

    private

    def setup_auth_integration
      if @access_token_callback
        setup_third_party_auth
      else
        setup_session_auth
      end
    end

    def setup_third_party_auth
      token = @access_token_callback.call
      @realtime_client.set_auth(token) if token
    end

    def setup_session_auth
      @last_realtime_token = nil
      @auth_subscription = @auth_client.on_auth_state_change do |event, session|
        handle_auth_event(event, session)
      end
    end

    def handle_auth_event(event, session)
      if TOKEN_EVENTS.include?(event)
        propagate_token(session)
      elsif event == :signed_out
        reset_realtime_token
      end
    end

    def propagate_token(session)
      token = session&.access_token
      return if token == @last_realtime_token

      @last_realtime_token = token
      @realtime_client.set_auth(token)
    end

    def reset_realtime_token
      @last_realtime_token = nil
      @realtime_client.set_auth(nil)
    end

    def resolve_current_token
      if @access_token_callback
        @access_token_callback.call
      elsif @auth_client
        session_result = @auth_client.get_session
        session_result[:session]&.access_token
      end
    rescue StandardError
      @api_key
    end
  end
end
