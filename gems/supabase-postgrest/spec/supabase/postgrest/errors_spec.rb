# frozen_string_literal: true

RSpec.describe "PostgREST Error Handling and Builder" do
  let(:base_url) { "http://localhost:3000/rest/v1" }
  let(:client) { Supabase::PostgREST::Client.new(url: base_url, headers: {}) }

  # ---------------------------------------------------------------------------
  # Error Hierarchy
  # ---------------------------------------------------------------------------
  describe Supabase::PostgREST::PostgrestError do
    it "inherits from StandardError" do
      expect(described_class.superclass).to eq(StandardError)
    end

    it "stores message, details, hint, and code" do
      err = described_class.new("msg", details: "det", hint: "hnt", code: "CODE")
      expect(err.message).to eq("msg")
      expect(err.details).to eq("det")
      expect(err.hint).to eq("hnt")
      expect(err.code).to eq("CODE")
    end

    it "defaults optional fields to nil" do
      err = described_class.new("msg")
      expect(err.details).to be_nil
      expect(err.hint).to be_nil
      expect(err.code).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # EH: Error Handling Tests
  # ---------------------------------------------------------------------------
  describe "error handling" do
    it "EH-01: non-2xx JSON error is parsed into PostgrestError fields" do
      body = { "message" => "Relation not found", "details" => nil, "hint" => nil, "code" => "42P01" }
      stub_request(:get, "#{base_url}/nonexistent?select=*")
        .to_return(status: 404, body: JSON.generate(body), headers: { "content-type" => "application/json" })

      result = client.from("nonexistent").select.execute
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::PostgREST::PostgrestError)
      expect(result[:error].message).to eq("Relation not found")
      expect(result[:error].code).to eq("42P01")
      expect(result[:status]).to eq(404)
    end

    it "EH-02: non-2xx non-JSON error returns raw body as message" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(status: 500, body: "Internal Server Error", headers: {})

      result = client.from("users").select.execute
      expect(result[:error]).to be_a(Supabase::PostgREST::PostgrestError)
      expect(result[:error].message).to eq("Internal Server Error")
    end

    it "EH-03: network error returns PostgrestError with FETCH_ERROR code" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

      result = client.from("users").select.execute
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::PostgREST::PostgrestError)
      expect(result[:error].code).to eq("FETCH_ERROR")
      expect(result[:status]).to eq(0)
      expect(result[:status_text]).to eq("")
    end

    it "EH-04: timeout error returns PostgrestError with FETCH_ERROR code" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_raise(Faraday::TimeoutError.new("execution expired"))

      result = client.from("users").select.execute
      expect(result[:error]).to be_a(Supabase::PostgREST::PostgrestError)
      expect(result[:error].code).to eq("FETCH_ERROR")
    end

    it "EH-05: 2xx response returns no error" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      result = client.from("users").select.execute
      expect(result[:error]).to be_nil
      expect(result[:data]).to eq([])
    end

    it "EH-06: throw_on_error raises PostgrestError on HTTP error" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(
          status: 404,
          body: '{"message":"Not found","code":"42P01"}',
          headers: { "content-type" => "application/json" }
        )

      expect do
        client.from("users").select.throw_on_error.execute
      end.to raise_error(Supabase::PostgREST::PostgrestError, "Not found")
    end

    it "EH-07: throw_on_error raises PostgrestError on network error" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

      expect do
        client.from("users").select.throw_on_error.execute
      end.to raise_error(Supabase::PostgREST::PostgrestError)
    end

    it "EH-08: throw_on_error does not raise on success" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      result = client.from("users").select.throw_on_error.execute
      expect(result[:data]).to eq([])
      expect(result[:error]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # Response parsing
  # ---------------------------------------------------------------------------
  describe "response parsing" do
    it "parses JSON response" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(status: 200, body: '[{"id":1}]', headers: { "content-type" => "application/json" })

      result = client.from("users").select.execute
      expect(result[:data]).to eq([{ "id" => 1 }])
    end

    it "parses vnd.pgrst content type as JSON" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(
          status: 200,
          body: '{"id":1}',
          headers: { "content-type" => "application/vnd.pgrst.object+json" }
        )

      result = client.from("users").select.single.execute
      expect(result[:data]).to eq("id" => 1)
    end

    it "returns CSV response as string" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(status: 200, body: "id,name\n1,Alice", headers: { "content-type" => "text/csv" })

      result = client.from("users").select.csv.execute
      expect(result[:data]).to eq("id,name\n1,Alice")
    end

    it "parses Content-Range header for count" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(
          status: 200,
          body: "[]",
          headers: { "content-type" => "application/json", "content-range" => "0-9/100" }
        )

      result = client.from("users").select.execute
      expect(result[:count]).to eq(100)
    end

    it "returns nil count when Content-Range has *" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(
          status: 200,
          body: "[]",
          headers: { "content-type" => "application/json", "content-range" => "0-9/*" }
        )

      result = client.from("users").select.execute
      expect(result[:count]).to be_nil
    end

    it "returns nil count when no Content-Range header" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      result = client.from("users").select.execute
      expect(result[:count]).to be_nil
    end

    it "result includes status and status_text" do
      stub_request(:get, "#{base_url}/users?select=*")
        .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

      result = client.from("users").select.execute
      expect(result[:status]).to eq(200)
      expect(result[:status_text]).to be_a(String)
    end
  end

  # ---------------------------------------------------------------------------
  # BI: Builder Immutability
  # ---------------------------------------------------------------------------
  describe "builder immutability" do
    it "BI-01: from() returns independent builders" do
      qb1 = client.from("users")
      qb2 = client.from("users")
      qb1.select("id")
      # qb2 should still have a clean URL
      expect(qb2.url.query).to be_nil
    end

    it "BI-02: throw_on_error returns a new builder" do
      builder = client.from("users").select
      throwing = builder.throw_on_error
      expect(throwing).not_to be(builder)
    end

    it "BI-03: FilterBuilder#select returns a new builder" do
      builder = client.from("users").insert({ name: "Alice" })
      with_select = builder.select("id")
      expect(with_select).not_to be(builder)
    end
  end

  # ---------------------------------------------------------------------------
  # Custom fetch proc
  # ---------------------------------------------------------------------------
  describe "custom fetch proc" do
    it "uses the provided fetch proc for requests" do
      called = false
      fetch = lambda { |_timeout|
        called = true
        Faraday.new do |f|
          f.adapter :test do |stub|
            stub.get("/rest/v1/users?select=*") do
              [200, { "content-type" => "application/json" }, "[]"]
            end
          end
        end
      }

      c = Supabase::PostgREST::Client.new(url: base_url, headers: {}, fetch: fetch)
      c.from("users").select.execute
      expect(called).to be true
    end
  end
end
