# frozen_string_literal: true

RSpec.describe "PostgREST CRUD Operations" do
  let(:base_url) { "http://localhost:3000/rest/v1" }
  let(:client) { Supabase::PostgREST::Client.new(url: base_url, headers: { "apikey" => "test-key" }) }

  # ---------------------------------------------------------------------------
  # SE: SELECT Operations
  # ---------------------------------------------------------------------------
  describe "SELECT" do
    it "SE-01: select('*') sends GET with ?select=*" do
      stub = stub_request(:get, "#{base_url}/users?select=*")
             .to_return(status: 200, body: '[{"id":1}]', headers: { "content-type" => "application/json" })

      result = client.from("users").select.execute
      expect(stub).to have_been_requested
      expect(result[:data]).to eq([{ "id" => 1 }])
      expect(result[:error]).to be_nil
      expect(result[:status]).to eq(200)
    end

    it "SE-02: select with specific columns" do
      stub = stub_request(:get, "#{base_url}/users?select=id,name,email")
             .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      client.from("users").select("id, name, email").execute
      expect(stub).to have_been_requested
    end

    it "SE-03: select strips whitespace from columns" do
      stub = stub_request(:get, "#{base_url}/users?select=id,name")
             .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      client.from("users").select("id , name").execute
      expect(stub).to have_been_requested
    end

    it "SE-04: select with head: true uses HEAD method" do
      stub = stub_request(:head, "#{base_url}/users?select=*")
             .to_return(status: 200, body: "", headers: { "content-range" => "0-0/5" })

      client.from("users").select(head: true).execute
      expect(stub).to have_been_requested
    end

    it "SE-05: select with count: :exact adds Prefer header" do
      stub = stub_request(:get, "#{base_url}/users?select=*")
             .with(headers: { "Prefer" => "count=exact" })
             .to_return(
               status: 200,
               body: "[]",
               headers: { "content-type" => "application/json", "content-range" => "*/10" }
             )

      result = client.from("users").select(count: :exact).execute
      expect(stub).to have_been_requested
      expect(result[:count]).to eq(10)
    end

    it "SE-06: select with count: :planned" do
      stub = stub_request(:get, "#{base_url}/users?select=*")
             .with(headers: { "Prefer" => "count=planned" })
             .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      client.from("users").select(count: :planned).execute
      expect(stub).to have_been_requested
    end

    it "SE-07: select with count: :estimated" do
      stub = stub_request(:get, "#{base_url}/users?select=*")
             .with(headers: { "Prefer" => "count=estimated" })
             .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      client.from("users").select(count: :estimated).execute
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # IN: INSERT Operations
  # ---------------------------------------------------------------------------
  describe "INSERT" do
    it "IN-01: insert a single row with POST" do
      stub = stub_request(:post, "#{base_url}/users")
             .with(
               body: '{"name":"Alice","email":"alice@test.com"}',
               headers: { "Content-Type" => "application/json" }
             )
             .to_return(status: 201, body: "", headers: { "content-type" => "application/json" })

      result = client.from("users").insert({ name: "Alice", email: "alice@test.com" }).execute
      expect(stub).to have_been_requested
      expect(result[:status]).to eq(201)
    end

    it "IN-02: bulk insert sets columns param from union of keys" do
      stub = stub_request(:post, %r{#{Regexp.escape(base_url)}/users\?columns=})
             .to_return(status: 201, body: "", headers: { "content-type" => "application/json" })

      rows = [
        { name: "Alice", email: "alice@test.com" },
        { name: "Bob", phone: "555-1234" }
      ]
      client.from("users").insert(rows).execute

      expect(stub).to have_been_requested
      expect(WebMock::RequestRegistry.instance.requested_signatures.hash.keys.first.uri.query)
        .to include("columns=name,email,phone")
    end

    it "IN-03: insert with count: :exact adds Prefer header" do
      stub = stub_request(:post, "#{base_url}/users")
             .with(headers: { "Prefer" => "count=exact" })
             .to_return(status: 201, body: "", headers: { "content-type" => "application/json" })

      client.from("users").insert({ name: "Alice" }, count: :exact).execute
      expect(stub).to have_been_requested
    end

    it "IN-04: insert with default_to_null: false adds Prefer: missing=default" do
      stub = stub_request(:post, "#{base_url}/users")
             .with(headers: { "Prefer" => "missing=default" })
             .to_return(status: 201, body: "", headers: { "content-type" => "application/json" })

      client.from("users").insert({ name: "Alice" }, default_to_null: false).execute
      expect(stub).to have_been_requested
    end

    it "IN-05: insert().select() adds return=representation" do
      stub = stub_request(:post, %r{#{Regexp.escape(base_url)}/users})
             .with(headers: { "Prefer" => "return=representation" })
             .to_return(
               status: 201,
               body: '[{"id":1,"name":"Alice"}]',
               headers: { "content-type" => "application/json" }
             )

      result = client.from("users").insert({ name: "Alice" }).select.execute
      expect(stub).to have_been_requested
      expect(result[:data]).to eq([{ "id" => 1, "name" => "Alice" }])
    end
  end

  # ---------------------------------------------------------------------------
  # UP: UPDATE Operations
  # ---------------------------------------------------------------------------
  describe "UPDATE" do
    it "UP-01: update sends PATCH with JSON body" do
      stub = stub_request(:patch, "#{base_url}/users?id=eq.1")
             .with(
               body: '{"email":"new@test.com"}',
               headers: { "Content-Type" => "application/json" }
             )
             .to_return(status: 200, body: "", headers: { "content-type" => "application/json" })

      client.from("users").update({ email: "new@test.com" }).eq("id", 1).execute
      expect(stub).to have_been_requested
    end

    it "UP-02: update with count adds Prefer header" do
      stub = stub_request(:patch, "#{base_url}/users?id=eq.1")
             .with(headers: { "Prefer" => "count=exact" })
             .to_return(status: 200, body: "", headers: { "content-type" => "application/json" })

      client.from("users").update({ email: "new@test.com" }, count: :exact).eq("id", 1).execute
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # US: UPSERT Operations
  # ---------------------------------------------------------------------------
  describe "UPSERT" do
    it "US-01: upsert sends POST with resolution=merge-duplicates" do
      stub = stub_request(:post, "#{base_url}/users")
             .with(headers: { "Prefer" => /resolution=merge-duplicates/ })
             .to_return(status: 201, body: "", headers: { "content-type" => "application/json" })

      client.from("users").upsert({ id: 1, name: "Alice" }).execute
      expect(stub).to have_been_requested
    end

    it "US-02: upsert with ignore_duplicates sets resolution=ignore-duplicates" do
      stub = stub_request(:post, "#{base_url}/users")
             .with(headers: { "Prefer" => /resolution=ignore-duplicates/ })
             .to_return(status: 201, body: "", headers: { "content-type" => "application/json" })

      client.from("users").upsert({ id: 1, name: "Alice" }, ignore_duplicates: true).execute
      expect(stub).to have_been_requested
    end

    it "US-03: upsert with on_conflict sets query param" do
      stub = stub_request(:post, %r{#{Regexp.escape(base_url)}/users.*on_conflict=id})
             .to_return(status: 201, body: "", headers: { "content-type" => "application/json" })

      client.from("users").upsert({ id: 1, name: "Alice" }, on_conflict: "id").execute
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # DE: DELETE Operations
  # ---------------------------------------------------------------------------
  describe "DELETE" do
    it "DE-01: delete sends DELETE method" do
      stub = stub_request(:delete, "#{base_url}/users?id=eq.1")
             .to_return(status: 200, body: "", headers: { "content-type" => "application/json" })

      client.from("users").delete.eq("id", 1).execute
      expect(stub).to have_been_requested
    end

    it "DE-02: delete with count adds Prefer header" do
      stub = stub_request(:delete, "#{base_url}/users?id=eq.1")
             .with(headers: { "Prefer" => "count=exact" })
             .to_return(status: 200, body: "", headers: { "content-type" => "application/json" })

      client.from("users").delete(count: :exact).eq("id", 1).execute
      expect(stub).to have_been_requested
    end

    it "DE-03: delete().select() adds return=representation" do
      stub = stub_request(:delete, %r{#{Regexp.escape(base_url)}/users})
             .with(headers: { "Prefer" => "return=representation" })
             .to_return(
               status: 200,
               body: '[{"id":1,"name":"Alice"}]',
               headers: { "content-type" => "application/json" }
             )

      result = client.from("users").delete.eq("id", 1).select.execute
      expect(stub).to have_been_requested
      expect(result[:data]).to eq([{ "id" => 1, "name" => "Alice" }])
    end
  end
end
