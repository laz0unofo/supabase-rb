# frozen_string_literal: true

RSpec.describe "Auth Utilities" do
  let(:base_url) { "https://test.supabase.co/auth/v1" }
  let(:api_key) { "test-api-key" }

  # Helper to build a valid JWT token for testing
  def build_jwt(payload = {})
    header = Base64.urlsafe_encode64('{"alg":"HS256","typ":"JWT"}', padding: false)
    default_payload = { "sub" => "user-123", "exp" => Time.now.to_i + 3600 }
    merged = default_payload.merge(payload)
    encoded_payload = Base64.urlsafe_encode64(JSON.generate(merged), padding: false)
    signature = Base64.urlsafe_encode64("fake-signature", padding: false)
    "#{header}.#{encoded_payload}.#{signature}"
  end

  describe "JWT (JW-01 through JW-03)" do
    describe ".decode" do
      it "JW-01: decodes a valid JWT and returns the payload" do
        token = build_jwt("sub" => "abc-123", "email" => "test@example.com")
        result = Supabase::Auth::JWT.decode(token)

        expect(result).to be_a(Hash)
        expect(result["sub"]).to eq("abc-123")
        expect(result["email"]).to eq("test@example.com")
      end

      it "JW-02: returns nil for an invalid JWT (not 3 parts)" do
        expect(Supabase::Auth::JWT.decode("invalid")).to be_nil
        expect(Supabase::Auth::JWT.decode("a.b")).to be_nil
        expect(Supabase::Auth::JWT.decode("")).to be_nil
      end

      it "JW-03: returns nil for a JWT with invalid JSON payload" do
        header = Base64.urlsafe_encode64("header", padding: false)
        payload = Base64.urlsafe_encode64("not-json", padding: false)
        sig = Base64.urlsafe_encode64("sig", padding: false)
        expect(Supabase::Auth::JWT.decode("#{header}.#{payload}.#{sig}")).to be_nil
      end
    end
  end

  describe "Base64URL (B6-01 through B6-05)" do
    describe ".base64url_decode" do
      it "B6-01: decodes standard base64url without padding" do
        encoded = Base64.urlsafe_encode64("hello world", padding: false)
        result = Supabase::Auth::JWT.base64url_decode(encoded)
        expect(result).to eq("hello world")
      end

      it "B6-02: decodes base64url with padding" do
        encoded = Base64.urlsafe_encode64("hello world", padding: true)
        result = Supabase::Auth::JWT.base64url_decode(encoded)
        expect(result).to eq("hello world")
      end

      it "B6-03: handles URL-safe characters (- and _)" do
        # Binary data with bytes that would produce + and / in standard base64
        data = [0xFF, 0xFE, 0xFD].pack("C*")
        encoded = Base64.urlsafe_encode64(data, padding: false)
        result = Supabase::Auth::JWT.base64url_decode(encoded)
        expect(result).to eq(data)
      end

      it "B6-04: decodes empty string" do
        result = Supabase::Auth::JWT.base64url_decode("")
        expect(result).to eq("")
      end

      it "B6-05: decodes strings of various lengths (padding edge cases)" do
        # 1 byte -> 2 chars, needs 2 padding
        result1 = Supabase::Auth::JWT.base64url_decode(Base64.urlsafe_encode64("a", padding: false))
        expect(result1).to eq("a")

        # 2 bytes -> 3 chars, needs 1 padding
        result2 = Supabase::Auth::JWT.base64url_decode(Base64.urlsafe_encode64("ab", padding: false))
        expect(result2).to eq("ab")

        # 3 bytes -> 4 chars, no padding needed
        result3 = Supabase::Auth::JWT.base64url_decode(Base64.urlsafe_encode64("abc", padding: false))
        expect(result3).to eq("abc")
      end
    end
  end

  describe "PKCE (PK-01 through PK-03)" do
    describe ".generate_code_verifier" do
      it "PK-01: generates a 112-character hex string" do
        verifier = Supabase::Auth::PKCE.generate_code_verifier
        expect(verifier).to be_a(String)
        expect(verifier.length).to eq(112)
        expect(verifier).to match(/\A[0-9a-f]+\z/)
      end
    end

    describe ".generate_code_challenge" do
      it "PK-02: generates a base64url-encoded SHA-256 challenge without padding" do
        verifier = "test-verifier-string"
        challenge = Supabase::Auth::PKCE.generate_code_challenge(verifier)

        expect(challenge).to be_a(String)
        expect(challenge).not_to include("=")
        expect(challenge).not_to include("+")
        expect(challenge).not_to include("/")

        # Verify it matches the expected SHA-256 hash
        expected_digest = Digest::SHA256.digest(verifier)
        expected_challenge = Base64.urlsafe_encode64(expected_digest, padding: false)
        expect(challenge).to eq(expected_challenge)
      end
    end

    describe ".challenge_method" do
      it "PK-03: returns s256" do
        expect(Supabase::Auth::PKCE.challenge_method).to eq("s256")
      end
    end
  end

  describe "MemoryStorage (SA-01 through SA-03)" do
    let(:storage) { Supabase::Auth::MemoryStorage.new }

    it "SA-01: stores and retrieves items" do
      storage.set_item("key", "value")
      expect(storage.get_item("key")).to eq("value")
    end

    it "SA-02: returns nil for missing items" do
      expect(storage.get_item("nonexistent")).to be_nil
    end

    it "SA-03: removes items and returns the deleted value" do
      storage.set_item("key", "value")
      removed = storage.remove_item("key")
      expect(removed).to eq("value")
      expect(storage.get_item("key")).to be_nil
    end
  end

  describe "Lock (LK-01 through LK-04)" do
    it "LK-01: acquires and releases the lock" do
      lock = Supabase::Auth::Lock.new
      result = lock.with_lock { 42 }
      expect(result).to eq(42)
    end

    it "LK-02: serializes concurrent access" do
      lock = Supabase::Auth::Lock.new
      counter = 0
      threads = 10.times.map do
        Thread.new do
          lock.with_lock do
            current = counter
            sleep(0.001)
            counter = current + 1
          end
        end
      end
      threads.each(&:join)
      expect(counter).to eq(10)
    end

    it "LK-03: raises Timeout::Error when lock cannot be acquired" do
      lock = Supabase::Auth::Lock.new(timeout: 0.1)
      # Hold the lock in another thread
      barrier = Queue.new
      thread = Thread.new do
        lock.with_lock do
          barrier.push(true)
          sleep(1)
        end
      end
      barrier.pop # Wait until the lock is held

      expect { lock.with_lock { nil } }.to raise_error(Timeout::Error)

      thread.kill
      thread.join(1)
    end

    it "LK-04: uses configurable timeout" do
      lock = Supabase::Auth::Lock.new(timeout: 0.05)
      barrier = Queue.new
      thread = Thread.new do
        lock.with_lock do
          barrier.push(true)
          sleep(1)
        end
      end
      barrier.pop

      start = Time.now
      expect { lock.with_lock { nil } }.to raise_error(Timeout::Error)
      elapsed = Time.now - start
      expect(elapsed).to be < 0.5

      thread.kill
      thread.join(1)
    end
  end

  describe "ErrorClassifier" do
    def build_response(status, body, content_type: "application/json")
      instance_double(Faraday::Response, status: status, body: body,
                                         headers: { "content-type" => content_type })
    end

    describe "HE-01: classifies 4xx JSON as AuthApiError" do
      it "returns AuthApiError with message, status, code" do
        body = '{"message":"Invalid email","error_code":"invalid_email"}'
        response = build_response(422, body)
        error = Supabase::Auth::ErrorClassifier.classify_response(response)

        expect(error).to be_a(Supabase::Auth::AuthApiError)
        expect(error.message).to eq("Invalid email")
        expect(error.status).to eq(422)
        expect(error.code).to eq("invalid_email")
      end
    end

    describe "HE-02: classifies 4xx non-JSON as AuthUnknownError" do
      it "returns AuthUnknownError with raw body" do
        response = build_response(400, "Bad Request", content_type: "text/plain")
        error = Supabase::Auth::ErrorClassifier.classify_response(response)

        expect(error).to be_a(Supabase::Auth::AuthUnknownError)
        expect(error.message).to eq("Bad Request")
        expect(error.status).to eq(400)
      end
    end

    describe "HE-03: classifies 502/503/504 as AuthRetryableFetchError" do
      [502, 503, 504].each do |status|
        it "returns AuthRetryableFetchError for #{status}" do
          response = build_response(status, "Server Error")
          error = Supabase::Auth::ErrorClassifier.classify_response(response)

          expect(error).to be_a(Supabase::Auth::AuthRetryableFetchError)
          expect(error.status).to eq(status)
        end
      end
    end

    describe "HE-04: classifies network exceptions as AuthRetryableFetchError with status 0" do
      it "returns AuthRetryableFetchError with status 0" do
        exception = Faraday::ConnectionFailed.new("connection refused")
        error = Supabase::Auth::ErrorClassifier.classify_exception(exception)

        expect(error).to be_a(Supabase::Auth::AuthRetryableFetchError)
        expect(error.status).to eq(0)
        expect(error.context).to eq(exception)
      end
    end

    describe "HE-05: classifies weak_password as AuthWeakPasswordError" do
      it "returns AuthWeakPasswordError with reasons" do
        body = JSON.generate(
          "error_code" => "weak_password",
          "message" => "Password too short",
          "weak_password" => { "reasons" => ["too short", "no special chars"] }
        )
        response = build_response(422, body)
        error = Supabase::Auth::ErrorClassifier.classify_response(response)

        expect(error).to be_a(Supabase::Auth::AuthWeakPasswordError)
        expect(error.reasons).to eq(["too short", "no special chars"])
        expect(error.code).to eq("weak_password")
      end
    end

    it "returns nil for successful responses (200-299)" do
      response = build_response(200, '{"ok":true}')
      expect(Supabase::Auth::ErrorClassifier.classify_response(response)).to be_nil
    end
  end

  describe "Error hierarchy" do
    it "all auth errors inherit from AuthError" do
      expect(Supabase::Auth::AuthApiError.ancestors).to include(Supabase::Auth::AuthError)
      expect(Supabase::Auth::AuthRetryableFetchError.ancestors).to include(Supabase::Auth::AuthError)
      expect(Supabase::Auth::AuthUnknownError.ancestors).to include(Supabase::Auth::AuthError)
      expect(Supabase::Auth::AuthSessionMissingError.ancestors).to include(Supabase::Auth::AuthError)
      expect(Supabase::Auth::AuthInvalidTokenResponseError.ancestors).to include(Supabase::Auth::AuthError)
      expect(Supabase::Auth::AuthInvalidCredentialsError.ancestors).to include(Supabase::Auth::AuthError)
      expect(Supabase::Auth::AuthWeakPasswordError.ancestors).to include(Supabase::Auth::AuthError)
      expect(Supabase::Auth::AuthPKCEGrantCodeExchangeError.ancestors).to include(Supabase::Auth::AuthError)
    end

    it "AuthWeakPasswordError inherits from AuthApiError" do
      expect(Supabase::Auth::AuthWeakPasswordError.ancestors).to include(Supabase::Auth::AuthApiError)
    end

    it "all auth errors inherit from StandardError" do
      expect(Supabase::Auth::AuthError.ancestors).to include(StandardError)
    end

    it "AuthError has context attribute" do
      error = Supabase::Auth::AuthError.new("msg", context: { key: "val" })
      expect(error.context).to eq({ key: "val" })
      expect(error.message).to eq("msg")
    end

    it "AuthApiError has status and code attributes" do
      error = Supabase::Auth::AuthApiError.new("msg", status: 422, code: "test_code")
      expect(error.status).to eq(422)
      expect(error.code).to eq("test_code")
    end
  end

  describe "ErrorGuards" do
    let(:client) do
      Supabase::Auth::Client.new(url: base_url, headers: { "apikey" => api_key })
    end

    it "auth_error? returns true for AuthError instances" do
      expect(client.auth_error?(Supabase::Auth::AuthError.new)).to be true
      expect(client.auth_error?(Supabase::Auth::AuthApiError.new)).to be true
      expect(client.auth_error?(StandardError.new)).to be false
    end

    it "auth_api_error? returns true for AuthApiError instances" do
      expect(client.auth_api_error?(Supabase::Auth::AuthApiError.new)).to be true
      expect(client.auth_api_error?(Supabase::Auth::AuthWeakPasswordError.new)).to be true
      expect(client.auth_api_error?(Supabase::Auth::AuthError.new)).to be false
    end

    it "auth_session_missing_error? returns true for AuthSessionMissingError instances" do
      expect(client.auth_session_missing_error?(Supabase::Auth::AuthSessionMissingError.new)).to be true
      expect(client.auth_session_missing_error?(Supabase::Auth::AuthError.new)).to be false
    end

    it "auth_retryable_fetch_error? returns true for AuthRetryableFetchError instances" do
      expect(client.auth_retryable_fetch_error?(Supabase::Auth::AuthRetryableFetchError.new)).to be true
      expect(client.auth_retryable_fetch_error?(Supabase::Auth::AuthError.new)).to be false
    end
  end

  describe "Session model" do
    it "initializes from string-keyed hash" do
      data = {
        "access_token" => "at", "refresh_token" => "rt",
        "expires_in" => 3600, "token_type" => "bearer",
        "user" => { "id" => "123" }
      }
      session = Supabase::Auth::Session.new(data)
      expect(session.access_token).to eq("at")
      expect(session.refresh_token).to eq("rt")
      expect(session.expires_in).to eq(3600)
      expect(session.token_type).to eq("bearer")
      expect(session.user).to eq({ "id" => "123" })
    end

    it "initializes from symbol-keyed hash" do
      data = { access_token: "at", refresh_token: "rt", expires_in: 3600 }
      session = Supabase::Auth::Session.new(data)
      expect(session.access_token).to eq("at")
    end

    it "computes expires_at from expires_in when not provided" do
      now = Time.now.to_i
      session = Supabase::Auth::Session.new("expires_in" => 3600)
      expect(session.expires_at).to be_within(2).of(now + 3600)
    end

    it "uses explicit expires_at when provided" do
      session = Supabase::Auth::Session.new("expires_at" => 9_999_999_999, "expires_in" => 3600)
      expect(session.expires_at).to eq(9_999_999_999)
    end

    it "returns nil for expires_at when neither expires_at nor expires_in provided" do
      session = Supabase::Auth::Session.new({})
      expect(session.expires_at).to be_nil
    end

    it "expired? returns true when past expiry" do
      session = Supabase::Auth::Session.new("expires_at" => Time.now.to_i - 100)
      expect(session.expired?).to be true
    end

    it "expired? returns false when before expiry" do
      session = Supabase::Auth::Session.new("expires_at" => Time.now.to_i + 3600)
      expect(session.expired?).to be false
    end

    it "expired? returns false when no expires_at" do
      session = Supabase::Auth::Session.new({})
      expect(session.expired?).to be false
    end

    it "to_h returns string-keyed hash" do
      data = {
        "access_token" => "at", "refresh_token" => "rt",
        "expires_in" => 3600, "expires_at" => 9_999_999_999,
        "token_type" => "bearer", "user" => { "id" => "123" }
      }
      session = Supabase::Auth::Session.new(data)
      h = session.to_h
      expect(h["access_token"]).to eq("at")
      expect(h["refresh_token"]).to eq("rt")
      expect(h["expires_at"]).to eq(9_999_999_999)
    end
  end
end
