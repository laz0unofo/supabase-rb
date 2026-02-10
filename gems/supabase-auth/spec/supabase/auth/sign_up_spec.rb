# frozen_string_literal: true

RSpec.describe "Auth Sign Up" do
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

  describe "sign_up (SU-01 through SU-07)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "SU-01: signs up with email and password" do
      stub_request(:post, "#{base_url}/signup")
        .with(body: hash_including("email" => "test@example.com", "password" => "password123"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_up(email: "test@example.com", password: "password123")
      expect(result[:session]).to be_a(Supabase::Auth::Session)
      expect(result[:user]).to be_a(Hash)
    end

    it "SU-02: signs up with phone and password" do
      stub_request(:post, "#{base_url}/signup")
        .with(body: hash_including("phone" => "+1234567890", "password" => "password123", "channel" => "sms"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_up(phone: "+1234567890", password: "password123")
      expect(result[:session]).to be_a(Supabase::Auth::Session)
    end

    it "SU-03: raises error when neither email nor phone is provided" do
      expect do
        client.sign_up(password: "password123")
      end.to raise_error(Supabase::Auth::AuthInvalidCredentialsError, "Email or phone is required")
    end

    it "SU-04: includes custom user data" do
      stub_request(:post, "#{base_url}/signup")
        .with(body: hash_including("data" => { "name" => "Test User" }))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_up(email: "test@example.com", password: "password123", data: { "name" => "Test User" })
    end

    it "SU-05: includes captcha token" do
      stub_request(:post, "#{base_url}/signup")
        .with(body: hash_including("gotrue_meta_security" => { "captcha_token" => "captcha-123" }))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_up(email: "test@example.com", password: "password123", captcha_token: "captcha-123")
    end

    it "SU-06: returns user without session when email confirmation required" do
      stub_request(:post, "#{base_url}/signup")
        .to_return(status: 200,
                   body: JSON.generate("user" => { "id" => "user-123", "email" => "test@example.com" }),
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_up(email: "test@example.com", password: "password123")
      expect(result[:user]).to be_a(Hash)
      expect(result[:session]).to be_nil
    end

    it "SU-07: raises error on API failure" do
      stub_request(:post, "#{base_url}/signup")
        .to_return(status: 422, body: '{"message":"User already registered","error_code":"user_exists"}',
                   headers: { "Content-Type" => "application/json" })

      expect do
        client.sign_up(email: "test@example.com", password: "password123")
      end.to raise_error(Supabase::Auth::AuthApiError, "User already registered")
    end
  end

  describe "sign_up with PKCE" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers, flow_type: :pkce) }

    it "includes code_challenge and code_challenge_method" do
      stub_request(:post, "#{base_url}/signup")
        .with(body: hash_including("code_challenge_method" => "s256"))
        .to_return(status: 200,
                   body: JSON.generate("user" => { "id" => "user-123" }),
                   headers: { "Content-Type" => "application/json" })

      client.sign_up(email: "test@example.com", password: "password123")

      # Verify code verifier was stored
      verifier = client.storage.get_item("supabase.auth.token-code-verifier")
      expect(verifier).to be_a(String)
      expect(verifier.length).to eq(112)
    end
  end

  describe "Phone auth (PH-01 through PH-03)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "PH-01: signs up with phone includes default sms channel" do
      stub_request(:post, "#{base_url}/signup")
        .with(body: hash_including("phone" => "+1234567890", "channel" => "sms"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_up(phone: "+1234567890", password: "password123")
    end

    it "PH-02: signs in with phone via OTP" do
      stub_request(:post, "#{base_url}/otp")
        .with(body: hash_including("phone" => "+1234567890", "channel" => "sms"))
        .to_return(status: 200, body: '{"message_id":"msg-123"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_with_otp(phone: "+1234567890")
      expect(result[:message_id]).to eq("msg-123")
    end

    it "PH-03: verifies phone OTP" do
      stub_request(:post, "#{base_url}/verify")
        .with(body: hash_including("phone" => "+1234567890", "token" => "123456", "type" => "sms"))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.verify_otp(phone: "+1234567890", token: "123456", type: "sms")
      expect(result[:session]).to be_a(Supabase::Auth::Session)
    end
  end

  describe "Anonymous auth (AN-01 through AN-03)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    it "AN-01: signs in anonymously" do
      stub_request(:post, "#{base_url}/signup")
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      result = client.sign_in_anonymously
      expect(result[:session]).to be_a(Supabase::Auth::Session)
    end

    it "AN-02: includes custom data for anonymous sign-in" do
      stub_request(:post, "#{base_url}/signup")
        .with(body: hash_including("data" => { "role" => "guest" }))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_anonymously(data: { "role" => "guest" })
    end

    it "AN-03: includes captcha token for anonymous sign-in" do
      stub_request(:post, "#{base_url}/signup")
        .with(body: hash_including("gotrue_meta_security" => { "captcha_token" => "cap-123" }))
        .to_return(status: 200, body: JSON.generate(session_response),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_anonymously(captcha_token: "cap-123")
    end
  end
end
