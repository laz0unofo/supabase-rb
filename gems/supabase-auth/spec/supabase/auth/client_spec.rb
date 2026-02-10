# frozen_string_literal: true

RSpec.describe Supabase::Auth::Client do
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
    token = overrides[:access_token] || build_jwt
    {
      "access_token" => token,
      "refresh_token" => "refresh-token-123",
      "expires_in" => 3600,
      "token_type" => "bearer",
      "user" => { "id" => "user-123", "email" => "test@example.com" }
    }.merge(overrides)
  end

  describe "Client configuration (CF-01 through CF-05)" do
    it "CF-01: initializes with url and headers" do
      client = described_class.new(url: base_url, headers: default_headers)
      expect(client).to be_a(described_class)
      expect(client.storage).to be_a(Supabase::Auth::MemoryStorage)
      expect(client.flow_type).to eq(:implicit)
    end

    it "CF-02: uses MemoryStorage by default" do
      client = described_class.new(url: base_url, headers: default_headers)
      expect(client.storage).to be_a(Supabase::Auth::MemoryStorage)
    end

    it "CF-03: accepts custom storage" do
      custom_storage = Supabase::Auth::MemoryStorage.new
      client = described_class.new(url: base_url, headers: default_headers, storage: custom_storage)
      expect(client.storage).to be(custom_storage)
    end

    it "CF-04: accepts pkce flow_type" do
      client = described_class.new(url: base_url, headers: default_headers, flow_type: :pkce)
      expect(client.flow_type).to eq(:pkce)
    end

    it "CF-05: strips trailing slash from URL" do
      client = described_class.new(url: "#{base_url}/", headers: default_headers)

      stub_request(:get, "#{base_url}/user")
        .to_return(status: 200, body: '{"id":"user-123"}', headers: { "Content-Type" => "application/json" })

      # Store a session so get_user has a token
      token = build_jwt
      client.set_session(access_token: token, refresh_token: "rt")

      result = client.get_user
      expect(result[:error]).to be_nil
    end
  end

  describe "HTTP headers" do
    let(:client) { described_class.new(url: base_url, headers: default_headers) }

    it "sends X-Supabase-Api-Version header" do
      stub_request(:post, "#{base_url}/signup")
        .with(headers: { "X-Supabase-Api-Version" => "2024-01-01" })
        .to_return(status: 200, body: '{"user":{"id":"123"}}', headers: { "Content-Type" => "application/json" })

      client.sign_up(email: "test@example.com", password: "password123")
    end

    it "sends X-Client-Info header" do
      stub_request(:post, "#{base_url}/signup")
        .with(headers: { "X-Client-Info" => "supabase-rb/#{Supabase::Auth::VERSION}" })
        .to_return(status: 200, body: '{"user":{"id":"123"}}', headers: { "Content-Type" => "application/json" })

      client.sign_up(email: "test@example.com", password: "password123")
    end

    it "sends Content-Type and Accept as application/json" do
      stub_request(:post, "#{base_url}/signup")
        .with(headers: { "Content-Type" => "application/json", "Accept" => "application/json" })
        .to_return(status: 200, body: '{"user":{"id":"123"}}', headers: { "Content-Type" => "application/json" })

      client.sign_up(email: "test@example.com", password: "password123")
    end

    it "includes client-level headers (apikey)" do
      stub_request(:post, "#{base_url}/signup")
        .with(headers: { "apikey" => api_key })
        .to_return(status: 200, body: '{"user":{"id":"123"}}', headers: { "Content-Type" => "application/json" })

      client.sign_up(email: "test@example.com", password: "password123")
    end
  end

  describe "get_session" do
    let(:client) { described_class.new(url: base_url, headers: default_headers) }

    it "returns nil session when no session exists" do
      result = client.get_session
      expect(result[:data][:session]).to be_nil
      expect(result[:error]).to be_nil
    end

    it "returns stored session when not expired" do
      token = build_jwt("exp" => Time.now.to_i + 3600)
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response(access_token: token)),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      result = client.get_session
      expect(result[:data][:session]).to be_a(Supabase::Auth::Session)
      expect(result[:data][:session].access_token).to eq(token)
      expect(result[:error]).to be_nil
    end

    it "auto-refreshes expired session" do
      # Use a custom storage with an already-expired session stored directly
      storage = Supabase::Auth::MemoryStorage.new
      expired_session = {
        "access_token" => build_jwt("exp" => Time.now.to_i - 100),
        "refresh_token" => "expired-rt",
        "expires_in" => 3600,
        "expires_at" => Time.now.to_i - 100,
        "token_type" => "bearer",
        "user" => { "id" => "user-123" }
      }
      storage.set_item("supabase.auth.token", JSON.generate(expired_session))

      fresh_client = described_class.new(url: base_url, headers: default_headers, storage: storage)
      fresh_token = build_jwt("exp" => Time.now.to_i + 3600)

      stub_request(:post, "#{base_url}/token?grant_type=refresh_token")
        .to_return(status: 200, body: JSON.generate(session_response(access_token: fresh_token)),
                   headers: { "Content-Type" => "application/json" })

      result = fresh_client.get_session
      expect(result[:data][:session].access_token).to eq(fresh_token)
      expect(result[:error]).to be_nil
    end
  end

  describe "get_user" do
    let(:client) { described_class.new(url: base_url, headers: default_headers) }

    it "returns user when session exists" do
      token = build_jwt
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response(access_token: token)),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      stub_request(:get, "#{base_url}/user")
        .with(headers: { "Authorization" => "Bearer #{token}" })
        .to_return(status: 200, body: '{"id":"user-123","email":"test@example.com"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.get_user
      expect(result[:data][:user]["id"]).to eq("user-123")
      expect(result[:error]).to be_nil
    end

    it "returns error when no session exists" do
      result = client.get_user
      expect(result[:data][:user]).to be_nil
      expect(result[:error]).to be_a(Supabase::Auth::AuthSessionMissingError)
    end

    it "uses provided JWT over session token" do
      custom_jwt = build_jwt("sub" => "custom-user")

      stub_request(:get, "#{base_url}/user")
        .with(headers: { "Authorization" => "Bearer #{custom_jwt}" })
        .to_return(status: 200, body: '{"id":"custom-user"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.get_user(jwt: custom_jwt)
      expect(result[:data][:user]["id"]).to eq("custom-user")
    end
  end
end
