# frozen_string_literal: true

RSpec.describe "Auth Session Management" do
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

  describe "set_session (SM-01 through SM-03)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "SM-01: sets session from valid tokens" do
      token = build_jwt("sub" => "user-456")
      result = client.set_session(access_token: token, refresh_token: "rt-123")

      expect(result[:session]).to be_a(Supabase::Auth::Session)
      expect(result[:session].access_token).to eq(token)
      expect(result[:session].refresh_token).to eq("rt-123")
    end

    it "SM-02: raises error for invalid token" do
      expect do
        client.set_session(access_token: "invalid-token", refresh_token: "rt-123")
      end.to raise_error(Supabase::Auth::AuthInvalidTokenResponseError)
    end

    it "SM-03: auto-refreshes expired token during set_session" do
      expired_token = build_jwt("exp" => Time.now.to_i - 100)
      fresh_token = build_jwt("exp" => Time.now.to_i + 3600)

      stub_request(:post, "#{base_url}/token?grant_type=refresh_token")
        .to_return(status: 200,
                   body: JSON.generate(session_response("access_token" => fresh_token)),
                   headers: { "Content-Type" => "application/json" })

      result = client.set_session(access_token: expired_token, refresh_token: "rt-123")
      expect(result[:session].access_token).to eq(fresh_token)
    end
  end

  describe "refresh_session (SM-04 through SM-06)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "SM-04: refreshes session with stored refresh token" do
      token = build_jwt
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response("access_token" => token)),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      fresh_token = build_jwt("exp" => Time.now.to_i + 7200)
      stub_request(:post, "#{base_url}/token?grant_type=refresh_token")
        .to_return(status: 200,
                   body: JSON.generate(session_response("access_token" => fresh_token)),
                   headers: { "Content-Type" => "application/json" })

      result = client.refresh_session
      expect(result[:session].access_token).to eq(fresh_token)
    end

    it "SM-05: refreshes session with provided session" do
      fresh_token = build_jwt
      stub_request(:post, "#{base_url}/token?grant_type=refresh_token")
        .with(body: hash_including("refresh_token" => "custom-rt"))
        .to_return(status: 200,
                   body: JSON.generate(session_response("access_token" => fresh_token)),
                   headers: { "Content-Type" => "application/json" })

      provided = Supabase::Auth::Session.new("refresh_token" => "custom-rt")
      client.refresh_session(current_session: provided)
    end

    it "SM-06: raises error when no refresh token available" do
      expect do
        client.refresh_session
      end.to raise_error(Supabase::Auth::AuthSessionMissingError)
    end
  end

  describe "sign_out (SO-01 through SO-03)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    before do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")
    end

    it "SO-01: signs out with global scope (default)" do
      stub_request(:post, "#{base_url}/logout")
        .with(body: hash_including("scope" => "global"))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      client.sign_out

      # Session should be removed
      session_result = client.get_session
      expect(session_result[:session]).to be_nil
    end

    it "SO-02: signs out with local scope (no server call)" do
      client.sign_out(scope: :local)

      # Session should be removed
      session_result = client.get_session
      expect(session_result[:session]).to be_nil
    end

    it "SO-03: signs out with others scope" do
      stub_request(:post, "#{base_url}/logout")
        .with(body: hash_including("scope" => "others"))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      client.sign_out(scope: :others)
    end
  end

  describe "Session persistence (SM-07 through SM-09)" do
    it "SM-07: persists session to storage" do
      storage = Supabase::Auth::MemoryStorage.new
      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers, storage: storage)

      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      stored = storage.get_item("supabase.auth.token")
      expect(stored).to be_a(String)
      parsed = JSON.parse(stored)
      expect(parsed["access_token"]).to be_a(String)
    end

    it "SM-08: loads session from storage" do
      storage = Supabase::Auth::MemoryStorage.new
      token = build_jwt("exp" => Time.now.to_i + 3600)
      session_data = {
        "access_token" => token,
        "refresh_token" => "rt-123",
        "expires_in" => 3600,
        "expires_at" => Time.now.to_i + 3600,
        "token_type" => "bearer",
        "user" => { "id" => "user-123" }
      }
      storage.set_item("supabase.auth.token", JSON.generate(session_data))

      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers, storage: storage)
      result = client.get_session
      expect(result[:session]).to be_a(Supabase::Auth::Session)
      expect(result[:session].access_token).to eq(token)
    end

    it "SM-09: does not persist session when persist_session is false" do
      storage = Supabase::Auth::MemoryStorage.new
      client = Supabase::Auth::Client.new(
        url: base_url, headers: default_headers, storage: storage, persist_session: false
      )

      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      # Should not be persisted to storage
      expect(storage.get_item("supabase.auth.token")).to be_nil

      # But should still be in memory
      result = client.get_session
      expect(result[:session]).to be_a(Supabase::Auth::Session)
    end
  end

  describe "User management (UM-01 through UM-04)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    before do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")
    end

    it "UM-01: updates user email" do
      stub_request(:put, "#{base_url}/user")
        .with(body: hash_including("email" => "new@example.com"))
        .to_return(status: 200,
                   body: '{"id":"user-123","email":"new@example.com"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.update_user(email: "new@example.com")
      expect(result[:user]["email"]).to eq("new@example.com")
    end

    it "UM-02: updates user password" do
      stub_request(:put, "#{base_url}/user")
        .with(body: hash_including("password" => "new-password"))
        .to_return(status: 200,
                   body: '{"id":"user-123"}',
                   headers: { "Content-Type" => "application/json" })

      client.update_user(password: "new-password")
    end

    it "UM-03: updates user metadata" do
      stub_request(:put, "#{base_url}/user")
        .with(body: hash_including("data" => { "name" => "New Name" }))
        .to_return(status: 200,
                   body: '{"id":"user-123"}',
                   headers: { "Content-Type" => "application/json" })

      client.update_user(data: { "name" => "New Name" })
    end

    it "UM-04: raises error when no session exists" do
      client.sign_out(scope: :local)

      expect do
        client.update_user(email: "new@example.com")
      end.to raise_error(Supabase::Auth::AuthSessionMissingError)
    end
  end

  describe "Password recovery (PR-01 through PR-02)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "PR-01: sends password recovery email" do
      stub_request(:post, "#{base_url}/recover")
        .with(body: hash_including("email" => "test@example.com"))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      result = client.reset_password_for_email("test@example.com")
      expect(result).to eq({})
    end

    it "PR-02: includes redirect_to and captcha_token" do
      stub_request(:post, "#{base_url}/recover")
        .with(body: hash_including(
          "email" => "test@example.com",
          "redirect_to" => "https://example.com/reset",
          "gotrue_meta_security" => { "captcha_token" => "cap-123" }
        ))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      client.reset_password_for_email(
        "test@example.com", redirect_to: "https://example.com/reset", captcha_token: "cap-123"
      )
    end
  end

  describe "Reauthenticate" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "sends reauthenticate request" do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      stub_request(:get, "#{base_url}/reauthenticate")
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      client.reauthenticate
    end

    it "raises error when no session" do
      expect do
        client.reauthenticate
      end.to raise_error(Supabase::Auth::AuthSessionMissingError)
    end
  end

  describe "Resend (RS-01 through RS-03)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "RS-01: resends email confirmation" do
      stub_request(:post, "#{base_url}/resend")
        .with(body: hash_including("type" => "signup", "email" => "test@example.com"))
        .to_return(status: 200, body: '{"message_id":"msg-123"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.resend(type: "signup", email: "test@example.com")
      expect(result[:message_id]).to eq("msg-123")
    end

    it "RS-02: resends phone OTP" do
      stub_request(:post, "#{base_url}/resend")
        .with(body: hash_including("type" => "sms", "phone" => "+1234567890"))
        .to_return(status: 200, body: '{"message_id":"msg-456"}',
                   headers: { "Content-Type" => "application/json" })

      client.resend(type: "sms", phone: "+1234567890")
    end

    it "RS-03: includes PKCE params when flow_type is pkce" do
      pkce_client = Supabase::Auth::Client.new(url: base_url, headers: default_headers, flow_type: :pkce)

      stub_request(:post, "#{base_url}/resend")
        .with(body: hash_including("code_challenge_method" => "s256"))
        .to_return(status: 200, body: '{"message_id":"msg-pkce"}',
                   headers: { "Content-Type" => "application/json" })

      pkce_client.resend(type: "signup", email: "test@example.com")
    end
  end
end
