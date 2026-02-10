# frozen_string_literal: true

RSpec.describe "Auth State Events" do
  let(:base_url) { "https://test.supabase.co/auth/v1" }
  let(:api_key) { "test-api-key" }
  let(:default_headers) { { "apikey" => api_key } }

  def build_jwt(payload = {})
    header = Base64.urlsafe_encode64('{"alg":"HS256","typ":"JWT"}', padding: false)
    default_payload = { "sub" => "user-123", "exp" => Time.now.to_i + 3600 }
    merged = default_payload.merge(payload)
    encoded_payload = Base64.urlsafe_encode64(JSON.generate(merged), padding: false)
    signature = Base64.urlsafe_encode64("fake-signature", padding: false)
    "#{header}.#{encoded_payload}.#{signature}"
  end

  def session_response(overrides = {})
    token = overrides.delete(:token) || build_jwt
    {
      "access_token" => token,
      "refresh_token" => "refresh-token-123",
      "expires_in" => 3600,
      "token_type" => "bearer",
      "user" => { "id" => "user-123", "email" => "test@example.com" }
    }.merge(overrides)
  end

  describe "on_auth_state_change (EV-01 through EV-06)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "EV-01: returns a Subscription with id and unsubscribe method" do
      subscription = client.on_auth_state_change { |_event, _session| nil }
      sleep(0.1)
      expect(subscription).to be_a(Supabase::Auth::Subscription)
      expect(subscription.id).to be_a(String)
      expect(subscription).to respond_to(:unsubscribe)
    end

    it "EV-02: fires INITIAL_SESSION asynchronously" do
      events = []
      client.on_auth_state_change { |event, _session| events << event }
      sleep(0.2) # Allow async delivery

      expect(events).to include(:initial_session)
    end

    it "EV-03: fires SIGNED_IN on sign-in" do
      events = []
      client.on_auth_state_change { |event, _session| events << event }
      sleep(0.1)

      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      expect(events).to include(:signed_in)
    end

    it "EV-04: fires SIGNED_OUT on sign-out" do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })
      client.sign_in_with_password(email: "test@example.com", password: "password123")

      events = []
      client.on_auth_state_change { |event, _session| events << event }
      sleep(0.1)

      client.sign_out(scope: :local)

      expect(events).to include(:signed_out)
    end

    it "EV-05: fires USER_UPDATED on user update" do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })
      client.sign_in_with_password(email: "test@example.com", password: "password123")

      events = []
      client.on_auth_state_change { |event, _session| events << event }
      sleep(0.1)

      stub_request(:put, "#{base_url}/user")
        .to_return(status: 200, body: '{"id":"user-123"}',
                   headers: { "Content-Type" => "application/json" })

      client.update_user(email: "new@example.com")

      expect(events).to include(:user_updated)
    end

    it "EV-06: unsubscribe stops event delivery" do
      events = []
      subscription = client.on_auth_state_change { |event, _session| events << event }
      sleep(0.1)

      subscription.unsubscribe
      events.clear

      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      expect(events).not_to include(:signed_in)
    end
  end

  describe "Event delivery" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "delivers events to all listeners in order" do
      listener_results = []

      client.on_auth_state_change { |event, _session| listener_results << "A:#{event}" }
      client.on_auth_state_change { |event, _session| listener_results << "B:#{event}" }
      sleep(0.2)

      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      expect(listener_results).to include("A:signed_in")
      expect(listener_results).to include("B:signed_in")
    end

    it "catches and logs listener errors without propagating" do
      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers, debug: true)

      events = []
      client.on_auth_state_change { |_event, _session| raise "boom" }
      client.on_auth_state_change { |event, _session| events << event }
      sleep(0.2)

      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      # Second listener should still receive events despite first one erroring
      expect(events).to include(:signed_in)
    end
  end

  describe "EVENTS constant" do
    it "contains all expected event types" do
      expect(Supabase::Auth::AuthStateEvents::EVENTS).to contain_exactly(
        :initial_session, :signed_in, :signed_out, :token_refreshed,
        :user_updated, :password_recovery, :mfa_challenge_verified
      )
    end
  end
end
