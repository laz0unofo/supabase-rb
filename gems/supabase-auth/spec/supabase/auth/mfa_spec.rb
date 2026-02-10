# frozen_string_literal: true

RSpec.describe "Auth MFA API" do
  let(:base_url) { "https://test.supabase.co/auth/v1" }
  let(:api_key) { "test-api-key" }
  let(:default_headers) { { "apikey" => api_key } }

  def build_jwt(payload = {})
    header = Base64.urlsafe_encode64('{"alg":"HS256","typ":"JWT"}', padding: false)
    default_payload = { "sub" => "user-123", "exp" => Time.now.to_i + 3600, "aal" => "aal1", "amr" => [] }
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

  def sign_in_client(client)
    stub_request(:post, "#{base_url}/token?grant_type=password")
      .to_return(status: 200, body: JSON.generate(session_response),
                 headers: { "Content-Type" => "application/json" })

    client.sign_in_with_password(email: "test@example.com", password: "password123")
  end

  describe "MFA enroll" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    before { sign_in_client(client) }

    it "enrolls a TOTP factor" do
      stub_request(:post, "#{base_url}/factors")
        .with(body: hash_including("factor_type" => "totp"))
        .to_return(status: 200,
                   body: '{"id":"factor-123","type":"totp","totp":{"qr_code":"data:image/png;base64,abc"}}',
                   headers: { "Content-Type" => "application/json" })

      result = client.mfa.enroll(factor_type: :totp)
      expect(result[:error]).to be_nil
      expect(result[:data]["id"]).to eq("factor-123")
    end

    it "enrolls a TOTP factor with friendly_name and issuer" do
      stub_request(:post, "#{base_url}/factors")
        .with(body: hash_including("factor_type" => "totp", "friendly_name" => "MyApp", "issuer" => "MyIssuer"))
        .to_return(status: 200,
                   body: '{"id":"factor-456","type":"totp"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.mfa.enroll(factor_type: :totp, friendly_name: "MyApp", issuer: "MyIssuer")
      expect(result[:error]).to be_nil
    end

    it "enrolls a phone factor" do
      stub_request(:post, "#{base_url}/factors")
        .with(body: hash_including("factor_type" => "phone", "phone" => "+1234567890"))
        .to_return(status: 200,
                   body: '{"id":"factor-phone","type":"phone"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.mfa.enroll(factor_type: :phone, phone: "+1234567890")
      expect(result[:error]).to be_nil
    end

    it "returns error when no session" do
      no_session_client = Supabase::Auth::Client.new(url: base_url, headers: default_headers)
      result = no_session_client.mfa.enroll(factor_type: :totp)
      expect(result[:error]).to be_a(Supabase::Auth::AuthSessionMissingError)
    end
  end

  describe "MFA challenge" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    before { sign_in_client(client) }

    it "creates a challenge for a factor" do
      stub_request(:post, "#{base_url}/factors/factor-123/challenge")
        .to_return(status: 200,
                   body: '{"id":"challenge-456","expires_at":"2099-01-01T00:00:00Z"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.mfa.challenge(factor_id: "factor-123")
      expect(result[:error]).to be_nil
      expect(result[:data]["id"]).to eq("challenge-456")
    end
  end

  describe "MFA verify" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    before { sign_in_client(client) }

    it "verifies a challenge and saves aal2 session" do
      aal2_token = build_jwt("aal" => "aal2", "amr" => [{ "method" => "mfa/totp" }])
      verify_response = session_response("access_token" => aal2_token)

      stub_request(:post, "#{base_url}/factors/factor-123/verify")
        .with(body: hash_including("challenge_id" => "chal-456", "code" => "123456"))
        .to_return(status: 200, body: JSON.generate(verify_response),
                   headers: { "Content-Type" => "application/json" })

      events = []
      client.on_auth_state_change { |event, _session| events << event }
      sleep(0.1)

      result = client.mfa.verify(factor_id: "factor-123", challenge_id: "chal-456", code: "123456")
      expect(result[:error]).to be_nil
      expect(events).to include(:mfa_challenge_verified)
    end
  end

  describe "MFA unenroll" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    before { sign_in_client(client) }

    it "unenrolls a factor" do
      stub_request(:delete, "#{base_url}/factors/factor-123")
        .to_return(status: 200, body: '{"id":"factor-123"}',
                   headers: { "Content-Type" => "application/json" })

      result = client.mfa.unenroll(factor_id: "factor-123")
      expect(result[:error]).to be_nil
    end
  end

  describe "MFA challenge_and_verify" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    before { sign_in_client(client) }

    it "combines challenge and verify in one call" do
      stub_request(:post, "#{base_url}/factors/factor-123/challenge")
        .to_return(status: 200,
                   body: '{"id":"chal-auto"}',
                   headers: { "Content-Type" => "application/json" })

      aal2_token = build_jwt("aal" => "aal2")
      stub_request(:post, "#{base_url}/factors/factor-123/verify")
        .with(body: hash_including("challenge_id" => "chal-auto", "code" => "654321"))
        .to_return(status: 200, body: JSON.generate(session_response("access_token" => aal2_token)),
                   headers: { "Content-Type" => "application/json" })

      result = client.mfa.challenge_and_verify(factor_id: "factor-123", code: "654321")
      expect(result[:error]).to be_nil
    end
  end

  describe "MFA list_factors" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }

    before { sign_in_client(client) }

    it "lists and categorizes factors" do
      user_data = {
        "id" => "user-123",
        "factors" => [
          { "id" => "f1", "factor_type" => "totp", "status" => "verified" },
          { "id" => "f2", "factor_type" => "phone", "status" => "verified" },
          { "id" => "f3", "factor_type" => "totp", "status" => "unverified" }
        ]
      }

      stub_request(:get, "#{base_url}/user")
        .to_return(status: 200, body: JSON.generate(user_data),
                   headers: { "Content-Type" => "application/json" })

      result = client.mfa.list_factors
      expect(result[:error]).to be_nil
      expect(result[:data][:all].length).to eq(3)
      expect(result[:data][:totp].length).to eq(1) # Only verified
      expect(result[:data][:phone].length).to eq(1)
    end
  end

  describe "MFA get_authenticator_assurance_level" do
    it "returns aal1 when no MFA method in AMR" do
      token = build_jwt("aal" => "aal1", "amr" => [{ "method" => "password" }])
      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers)

      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200,
                   body: JSON.generate(session_response("access_token" => token)),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      result = client.mfa.get_authenticator_assurance_level
      expect(result[:error]).to be_nil
      expect(result[:data][:current_level]).to eq(:aal1)
      expect(result[:data][:next_level]).to eq(:aal2)
    end

    it "returns aal2 when MFA method present in AMR" do
      token = build_jwt("aal" => "aal2", "amr" => [{ "method" => "password" }, { "method" => "mfa/totp" }])
      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers)

      stub_request(:post, "#{base_url}/token?grant_type=password")
        .to_return(status: 200,
                   body: JSON.generate(session_response("access_token" => token)),
                   headers: { "Content-Type" => "application/json" })

      client.sign_in_with_password(email: "test@example.com", password: "password123")

      result = client.mfa.get_authenticator_assurance_level
      expect(result[:error]).to be_nil
      expect(result[:data][:current_level]).to eq(:aal2)
      expect(result[:data][:next_level]).to eq(:aal2)
    end

    it "returns nil levels when no session" do
      client = Supabase::Auth::Client.new(url: base_url, headers: default_headers)

      result = client.mfa.get_authenticator_assurance_level
      expect(result[:error]).to be_nil
      expect(result[:data][:current_level]).to be_nil
      expect(result[:data][:next_level]).to be_nil
    end
  end
end
