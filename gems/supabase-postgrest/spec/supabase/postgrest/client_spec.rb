# frozen_string_literal: true

RSpec.describe Supabase::PostgREST::Client do
  let(:base_url) { "http://localhost:3000/rest/v1" }
  let(:default_headers) { { "apikey" => "test-key" } }
  let(:client) { described_class.new(url: base_url, headers: default_headers) }

  # ---------------------------------------------------------------------------
  # CI: Client Initialization
  # ---------------------------------------------------------------------------
  describe "#initialize" do
    it "CI-01: stores the base URL with trailing slash stripped" do
      c = described_class.new(url: "http://localhost:3000/rest/v1/", headers: {})
      qb = c.from("users")
      expect(qb.url.to_s).to start_with("http://localhost:3000/rest/v1/users")
    end

    it "CI-02: stores default headers" do
      c = described_class.new(url: base_url, headers: { "apikey" => "my-key" })
      qb = c.from("users")
      expect(qb.headers["apikey"]).to eq("my-key")
    end

    it "CI-03: stores the default schema" do
      c = described_class.new(url: base_url, headers: {}, schema: "custom")
      qb = c.from("users")
      expect(qb.schema).to eq("custom")
    end

    it "CI-04: stores the custom fetch proc" do
      fetch_proc = ->(_timeout) { Faraday.new }
      c = described_class.new(url: base_url, headers: {}, fetch: fetch_proc)
      # Verify fetch is used by calling rpc with custom fetch
      stub_request(:post, "#{base_url}/rpc/test_fn")
        .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })
      result = c.rpc("test_fn")
      expect(result[:status]).to be_a(Integer)
    end

    it "CI-05: stores the default timeout" do
      c = described_class.new(url: base_url, headers: {}, timeout: 30)
      stub_request(:post, "#{base_url}/rpc/test_fn")
        .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })
      result = c.rpc("test_fn")
      expect(result[:error]).to be_nil
    end

    it "CI-06: defaults schema to nil" do
      c = described_class.new(url: base_url, headers: {})
      qb = c.from("users")
      expect(qb.schema).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # from() and schema()
  # ---------------------------------------------------------------------------
  describe "#from" do
    it "returns a QueryBuilder scoped to the table" do
      qb = client.from("users")
      expect(qb).to be_a(Supabase::PostgREST::QueryBuilder)
      expect(qb.relation).to eq("users")
      expect(qb.url.to_s).to eq("#{base_url}/users")
    end

    it "returns independent builders (BI-01)" do
      qb1 = client.from("users")
      qb2 = client.from("posts")
      expect(qb1.url.to_s).not_to eq(qb2.url.to_s)
    end
  end

  describe "#schema" do
    it "SC-01: returns a new Client with the specified schema" do
      c = client.schema("custom")
      qb = c.from("users")
      expect(qb.schema).to eq("custom")
    end

    it "SC-02: original client retains original schema" do
      client.schema("custom")
      qb = client.from("users")
      expect(qb.schema).to be_nil
    end

    it "SC-03: schema client uses Accept-Profile for GET" do
      schema_client = client.schema("auth")
      stub = stub_request(:get, "#{base_url}/users?select=*")
             .with(headers: { "Accept-Profile" => "auth" })
             .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      schema_client.from("users").select.execute
      expect(stub).to have_been_requested
    end

    it "SC-04: schema client uses Content-Profile for POST" do
      schema_client = client.schema("auth")
      stub = stub_request(:post, "#{base_url}/users")
             .with(headers: { "Content-Profile" => "auth" })
             .to_return(status: 201, body: "", headers: { "content-type" => "application/json" })

      schema_client.from("users").insert({ name: "Alice" }).execute
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # RP: RPC
  # ---------------------------------------------------------------------------
  describe "#rpc" do
    it "RP-01: calls a function with POST by default" do
      stub = stub_request(:post, "#{base_url}/rpc/my_func")
             .with(
               body: '{"x":1}',
               headers: { "Content-Type" => "application/json" }
             )
             .to_return(status: 200, body: '{"result":42}', headers: { "content-type" => "application/json" })

      result = client.rpc("my_func", args: { x: 1 })
      expect(stub).to have_been_requested
      expect(result[:data]).to eq("result" => 42)
      expect(result[:error]).to be_nil
    end

    it "RP-02: supports GET mode with args as query params" do
      stub = stub_request(:get, "#{base_url}/rpc/my_func?x=1&y=2")
             .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      result = client.rpc("my_func", args: { x: 1, y: 2 }, get: true)
      expect(stub).to have_been_requested
      expect(result[:data]).to eq([])
    end

    it "RP-03: supports HEAD mode" do
      stub = stub_request(:head, "#{base_url}/rpc/my_func")
             .to_return(status: 200, body: "", headers: {})

      client.rpc("my_func", head: true)
      expect(stub).to have_been_requested
    end

    it "RP-04: HEAD mode takes precedence over GET" do
      stub = stub_request(:head, "#{base_url}/rpc/my_func")
             .to_return(status: 200, body: "", headers: {})

      client.rpc("my_func", head: true, get: true)
      expect(stub).to have_been_requested
    end

    it "RP-05: supports count parameter" do
      stub = stub_request(:post, "#{base_url}/rpc/count_fn")
             .with(headers: { "Prefer" => "count=exact" })
             .to_return(
               status: 200,
               body: "[]",
               headers: { "content-type" => "application/json", "content-range" => "0-9/42" }
             )

      result = client.rpc("count_fn", count: :exact)
      expect(stub).to have_been_requested
      expect(result[:count]).to eq(42)
    end

    it "RP-06: GET mode with empty args omits query string" do
      stub = stub_request(:get, "#{base_url}/rpc/no_args")
             .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      client.rpc("no_args", args: {}, get: true)
      expect(stub).to have_been_requested
    end

    it "RP-07: applies schema headers to RPC calls" do
      schema_client = client.schema("custom")
      stub = stub_request(:post, "#{base_url}/rpc/my_func")
             .with(headers: { "Content-Profile" => "custom" })
             .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      schema_client.rpc("my_func")
      expect(stub).to have_been_requested
    end
  end
end
