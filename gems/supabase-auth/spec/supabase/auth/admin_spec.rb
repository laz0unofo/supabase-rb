# frozen_string_literal: true

RSpec.describe "Auth Admin API" do
  let(:base_url) { "https://test.supabase.co/auth/v1" }
  let(:api_key) { "service-role-key" }
  let(:default_headers) { { "apikey" => api_key } }

  def build_jwt(payload = {})
    header = Base64.urlsafe_encode64('{"alg":"HS256","typ":"JWT"}', padding: false)
    default_payload = { "sub" => "user-123", "exp" => Time.now.to_i + 3600 }
    merged = default_payload.merge(payload)
    encoded_payload = Base64.urlsafe_encode64(JSON.generate(merged), padding: false)
    signature = Base64.urlsafe_encode64("fake-signature", padding: false)
    "#{header}.#{encoded_payload}.#{signature}"
  end

  describe "Admin API (AD-01 through AD-13)" do
    let(:client) { Supabase::Auth::Client.new(url: base_url, headers: default_headers) }
    let(:admin) { client.admin }

    it "AD-01: creates a user with email and password" do
      stub_request(:post, "#{base_url}/admin/users")
        .with(
          body: hash_including("email" => "new@example.com", "password" => "password123"),
          headers: { "Authorization" => "Bearer #{api_key}" }
        )
        .to_return(status: 200,
                   body: '{"id":"user-new","email":"new@example.com"}',
                   headers: { "Content-Type" => "application/json" })

      result = admin.create_user(email: "new@example.com", password: "password123")
      expect(result[:error]).to be_nil
      expect(result[:data]["email"]).to eq("new@example.com")
    end

    it "AD-02: creates a user with metadata and confirmation flags" do
      stub_request(:post, "#{base_url}/admin/users")
        .with(body: hash_including(
          "email" => "new@example.com",
          "user_metadata" => { "name" => "Test" },
          "app_metadata" => { "role" => "admin" },
          "email_confirm" => true
        ))
        .to_return(status: 200, body: '{"id":"user-new"}',
                   headers: { "Content-Type" => "application/json" })

      result = admin.create_user(
        email: "new@example.com",
        user_metadata: { "name" => "Test" },
        app_metadata: { "role" => "admin" },
        email_confirm: true
      )
      expect(result[:error]).to be_nil
    end

    it "AD-03: creates a user with phone" do
      stub_request(:post, "#{base_url}/admin/users")
        .with(body: hash_including("phone" => "+1234567890", "phone_confirm" => true))
        .to_return(status: 200, body: '{"id":"user-phone"}',
                   headers: { "Content-Type" => "application/json" })

      result = admin.create_user(phone: "+1234567890", phone_confirm: true)
      expect(result[:error]).to be_nil
    end

    it "AD-04: lists users without pagination" do
      stub_request(:get, "#{base_url}/admin/users")
        .with(headers: { "Authorization" => "Bearer #{api_key}" })
        .to_return(status: 200, body: '[{"id":"u1"},{"id":"u2"}]',
                   headers: { "Content-Type" => "application/json" })

      result = admin.list_users
      expect(result[:error]).to be_nil
      expect(result[:data]).to be_a(Array)
      expect(result[:data].length).to eq(2)
    end

    it "AD-05: lists users with pagination" do
      stub_request(:get, "#{base_url}/admin/users?page=1&per_page=10")
        .to_return(status: 200, body: '[{"id":"u1"}]',
                   headers: { "Content-Type" => "application/json" })

      result = admin.list_users(page: 1, per_page: 10)
      expect(result[:error]).to be_nil
    end

    it "AD-06: gets a user by ID" do
      stub_request(:get, "#{base_url}/admin/users/user-123")
        .to_return(status: 200, body: '{"id":"user-123","email":"test@example.com"}',
                   headers: { "Content-Type" => "application/json" })

      result = admin.get_user_by_id("user-123")
      expect(result[:error]).to be_nil
      expect(result[:data]["id"]).to eq("user-123")
    end

    it "AD-07: updates a user by ID" do
      stub_request(:put, "#{base_url}/admin/users/user-123")
        .with(body: hash_including("email" => "updated@example.com"))
        .to_return(status: 200, body: '{"id":"user-123","email":"updated@example.com"}',
                   headers: { "Content-Type" => "application/json" })

      result = admin.update_user_by_id("user-123", email: "updated@example.com")
      expect(result[:error]).to be_nil
      expect(result[:data]["email"]).to eq("updated@example.com")
    end

    it "AD-08: deletes a user (hard delete)" do
      stub_request(:delete, "#{base_url}/admin/users/user-123")
        .with(body: hash_including("should_soft_delete" => false))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      result = admin.delete_user("user-123")
      expect(result[:error]).to be_nil
    end

    it "AD-09: deletes a user (soft delete)" do
      stub_request(:delete, "#{base_url}/admin/users/user-123")
        .with(body: hash_including("should_soft_delete" => true))
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      result = admin.delete_user("user-123", should_soft_delete: true)
      expect(result[:error]).to be_nil
    end

    it "AD-10: invites a user by email" do
      stub_request(:post, "#{base_url}/invite")
        .with(body: hash_including("email" => "invite@example.com"))
        .to_return(status: 200, body: '{"id":"user-invited","email":"invite@example.com"}',
                   headers: { "Content-Type" => "application/json" })

      result = admin.invite_user_by_email("invite@example.com")
      expect(result[:error]).to be_nil
    end

    it "AD-11: invites a user with data and redirect_to" do
      stub_request(:post, "#{base_url}/invite")
        .with(body: hash_including(
          "email" => "invite@example.com",
          "data" => { "role" => "member" },
          "redirect_to" => "https://example.com/welcome"
        ))
        .to_return(status: 200, body: '{"id":"user-invited"}',
                   headers: { "Content-Type" => "application/json" })

      result = admin.invite_user_by_email(
        "invite@example.com", data: { "role" => "member" }, redirect_to: "https://example.com/welcome"
      )
      expect(result[:error]).to be_nil
    end

    it "AD-12: generates a link" do
      response_data = {
        "id" => "user-123",
        "email" => "test@example.com",
        "action_link" => "https://example.com/verify?token=abc",
        "email_otp" => "123456",
        "hashed_token" => "hash-abc",
        "redirect_to" => "https://example.com/",
        "verification_type" => "signup"
      }

      stub_request(:post, "#{base_url}/admin/generate_link")
        .with(body: hash_including("type" => "signup", "email" => "test@example.com"))
        .to_return(status: 200, body: JSON.generate(response_data),
                   headers: { "Content-Type" => "application/json" })

      result = admin.generate_link(type: "signup", email: "test@example.com")
      expect(result[:error]).to be_nil
      expect(result[:data][:properties][:action_link]).to eq("https://example.com/verify?token=abc")
      expect(result[:data][:properties][:email_otp]).to eq("123456")
      expect(result[:data][:properties][:hashed_token]).to eq("hash-abc")
      expect(result[:data][:properties][:verification_type]).to eq("signup")
      expect(result[:data][:user]["id"]).to eq("user-123")
    end

    it "AD-13: admin sign out with JWT" do
      custom_jwt = build_jwt("sub" => "target-user")
      stub_request(:post, "#{base_url}/logout")
        .with(
          body: hash_including("scope" => "global"),
          headers: { "Authorization" => "Bearer #{custom_jwt}" }
        )
        .to_return(status: 200, body: "{}", headers: { "Content-Type" => "application/json" })

      result = admin.sign_out(custom_jwt, scope: :global)
      expect(result[:error]).to be_nil
    end
  end

  describe "Admin authentication" do
    it "uses apikey header as authorization token" do
      client = Supabase::Auth::Client.new(url: base_url, headers: { "apikey" => "service-key" })

      stub_request(:get, "#{base_url}/admin/users")
        .with(headers: { "Authorization" => "Bearer service-key" })
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      result = client.admin.list_users
      expect(result[:error]).to be_nil
    end

    it "falls back to Authorization header when no apikey" do
      client = Supabase::Auth::Client.new(
        url: base_url, headers: { "Authorization" => "Bearer my-service-key" }
      )

      stub_request(:get, "#{base_url}/admin/users")
        .with(headers: { "Authorization" => "Bearer my-service-key" })
        .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      result = client.admin.list_users
      expect(result[:error]).to be_nil
    end
  end
end
