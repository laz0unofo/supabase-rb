# frozen_string_literal: true

RSpec.describe "Auth Sign In" do
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

  describe "sign_in_with_password (SI-01 through SI-04)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "SI-01: signs in with email and password" do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .with(body: hash_including("email" => "test@example.com", "password" => "password123"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_password(email: "test@example.com", password: "password123")
      expect(result[:error]).to be_nil
      expect(result[:data][:session]).to be_a(Supabase::Auth::Session)
      expect(result[:data][:user]).to be_a(Hash)
    end

    it "SI-02: signs in with phone and password" do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .with(body: hash_including("phone" => "+1234567890", "password" => "password123"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_password(phone: "+1234567890", password: "password123")
      expect(result[:error]).to be_nil
      expect(result[:data][:session]).to be_a(Supabase::Auth::Session)
    end

    it "SI-03: saves session after sign-in" do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      result = client.get_session
      expect(result[:data][:session]).to be_a(Supabase::Auth::Session)
    end

    it "SI-04: returns error on invalid credentials" do
      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 400,
                   body: '{"message":"Invalid login credentials","error_code":"invalid_credentials"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_password(email: "test@example.com", password: "wrong")
      expect(result[:error]).to be_a(Supabase::Auth::AuthApiError)
      expect(result[:error].message).to eq("Invalid login credentials")
    end
  end

  describe "sign_in_with_oauth (OA-01 through OA-05)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "OA-01: builds OAuth URL with provider" do
      result = client.sign_in_with_oauth(provider: "google")
      expect(result[:error]).to be_nil
      expect(result[:data][:provider]).to eq("google")
      expect(result[:data][:url]).to include("#{base_url}/authorize")
      expect(result[:data][:url]).to include("provider=google")
    end

    it "OA-02: includes redirect_to in OAuth URL" do
      result = client.sign_in_with_oauth(provider: "github", redirect_to: "https://example.com/callback")
      expect(result[:data][:url]).to include("redirect_to=")
      expect(result[:data][:url]).to include("example.com")
    end

    it "OA-03: includes scopes in OAuth URL" do
      result = client.sign_in_with_oauth(provider: "google", scopes: "email profile")
      expect(result[:data][:url]).to include("scopes=email+profile")
    end

    it "OA-04: includes query_params in OAuth URL" do
      result = client.sign_in_with_oauth(provider: "google", query_params: { "access_type" => "offline" })
      expect(result[:data][:url]).to include("access_type=offline")
    end

    it "OA-05: includes skip_browser_redirect in OAuth URL" do
      result = client.sign_in_with_oauth(provider: "google", skip_browser_redirect: true)
      expect(result[:data][:url]).to include("skip_browser_redirect=true")
    end
  end

  describe "sign_in_with_oauth with PKCE" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers, flow_type: :pkce) }

    it "includes code_challenge in OAuth URL" do
      result = client.sign_in_with_oauth(provider: "google")
      expect(result[:data][:url]).to include("code_challenge=")
      expect(result[:data][:url]).to include("code_challenge_method=s256")

      verifier = client.storage.get_item("supabase.auth.token-code-verifier")
      expect(verifier).to be_a(String)
      expect(verifier.length).to eq(112)
    end
  end

  describe "sign_in_with_otp (OT-01 through OT-05)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "OT-01: sends OTP to email" do
      stub_request(:post, "#{base_url}/otp")
        .with(body: hash_including("email" => "test@example.com"))
        .to_return(status: 200, body: '{"message_id":"msg-123"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_otp(email: "test@example.com")
      expect(result[:error]).to be_nil
      expect(result[:data][:message_id]).to eq("msg-123")
    end

    it "OT-02: sends OTP to phone" do
      stub_request(:post, "#{base_url}/otp")
        .with(body: hash_including("phone" => "+1234567890", "channel" => "sms"))
        .to_return(status: 200, body: '{"message_id":"msg-456"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_otp(phone: "+1234567890")
      expect(result[:error]).to be_nil
    end

    it "OT-03: includes should_create_user option" do
      stub_request(:post, "#{base_url}/otp")
        .with(body: hash_including("create_user" => false))
        .to_return(status: 200, body: '{"message_id":"msg-789"}',
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_otp(email: "test@example.com", should_create_user: false)
    end

    it "OT-04: includes captcha token" do
      stub_request(:post, "#{base_url}/otp")
        .with(body: hash_including("gotrue_meta_security" => { "captcha_token" => "cap-123" }))
        .to_return(status: 200, body: '{"message_id":"msg-abc"}',
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_otp(email: "test@example.com", captcha_token: "cap-123")
    end

    it "OT-05: includes PKCE params when flow_type is pkce" do
      pkce_client = Supabase::Auth::Client.new(url: base_url, headers: default_headers, flow_type: :pkce)

      stub_request(:post, "#{base_url}/otp")
        .with(body: hash_including("code_challenge_method" => "s256"))
        .to_return(status: 200, body: '{"message_id":"msg-pkce"}',
                   headers: { "Content-Type" => "application/json" })

      result = pkce_client.sign_in_with_otp(email: "test@example.com")
      expect(result[:error]).to be_nil
    end
  end

  describe "sign_in_with_id_token (IT-01 through IT-02)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "IT-01: signs in with ID token" do
      stub_request(:post, "#{base_url}/token?grant_type=id_token")
        .with(body: hash_including("provider" => "google", "token" => "id-token-123"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_id_token(provider: "google", token: "id-token-123")
      expect(result[:error]).to be_nil
      expect(result[:data][:session]).to be_a(Supabase::Auth::Session)
    end

    it "IT-02: includes optional nonce and access_token" do
      stub_request(:post, "#{base_url}/token?grant_type=id_token")
        .with(body: hash_including("nonce" => "nonce-123", "access_token" => "at-123"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_id_token(
        provider: "apple", token: "id-tok", nonce: "nonce-123", access_token: "at-123"
      )
      expect(result[:error]).to be_nil
    end
  end

  describe "sign_in_with_sso (SS-01 through SS-02)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "SS-01: signs in with SSO using domain" do
      stub_request(:post, "#{base_url}/sso")
        .with(body: hash_including("domain" => "example.com"))
        .to_return(status: 200, body: '{"url":"https://sso.example.com/auth"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_sso(domain: "example.com")
      expect(result[:error]).to be_nil
      expect(result[:data][:url]).to eq("https://sso.example.com/auth")
    end

    it "SS-02: signs in with SSO using provider_id" do
      stub_request(:post, "#{base_url}/sso")
        .with(body: hash_including("provider_id" => "sso-provider-123"))
        .to_return(status: 200, body: '{"url":"https://sso.provider.com/login"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_sso(provider_id: "sso-provider-123")
      expect(result[:error]).to be_nil
      expect(result[:data][:url]).to eq("https://sso.provider.com/login")
    end
  end

  describe "verify_otp" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "verifies email OTP with token_hash" do
      stub_request(:post, "#{base_url}/verify")
        .with(body: hash_including("type" => "magiclink", "token_hash" => "hash-123"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.verify_otp(type: "magiclink", token_hash: "hash-123")
      expect(result[:error]).to be_nil
      expect(result[:data][:session]).to be_a(Supabase::Auth::Session)
    end

    it "verifies email OTP with email and token" do
      stub_request(:post, "#{base_url}/verify")
        .with(body: hash_including("type" => "signup", "email" => "test@example.com", "token" => "123456"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.verify_otp(type: "signup", email: "test@example.com", token: "123456")
      expect(result[:error]).to be_nil
    end
  end

  describe "exchange_code_for_session" do
    it "exchanges auth code for session" do
      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers, flow_type: :pkce)

      # Store a code verifier
      verifier = Supabase::Auth::PKCE.generate_code_verifier
      client.storage.set_item("supabase.auth.token-code-verifier", verifier)

      stub_request(:post, "#{base_url}/token?grant_type=pkce")
        .with(body: hash_including("auth_code" => "auth-code-123", "code_verifier" => verifier))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.exchange_code_for_session("auth-code-123")
      expect(result[:error]).to be_nil
      expect(result[:data][:session]).to be_a(Supabase::Auth::Session)

      # Verifier should be consumed
      expect(client.storage.get_item("supabase.auth.token-code-verifier")).to be_nil
    end

    it "returns error when no code verifier in storage" do
      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers, flow_type: :pkce)

      result = client.exchange_code_for_session("auth-code-123")
      expect(result[:error]).to be_a(Supabase::Auth::AuthPKCEGrantCodeExchangeError)
    end

    it "emits password_recovery when verifier has PASSWORD_RECOVERY suffix" do
      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers, flow_type: :pkce)

      verifier = Supabase::Auth::PKCE.generate_code_verifier
      client.storage.set_item("supabase.auth.token-code-verifier", "#{verifier}/PASSWORD_RECOVERY")

      events = []
      client.on_auth_state_change { |event, _session| events << event }
      sleep(0.1) # Allow initial_session delivery

      stub_request(:post, "#{base_url}/token?grant_type=pkce")
        .with(body: hash_including("auth_code" => "code-123", "code_verifier" => verifier))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.exchange_code_for_session("code-123")
      sleep(0.1)

      expect(events).to include(:password_recovery)
    end
  end
end
