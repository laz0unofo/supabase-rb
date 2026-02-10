# frozen_string_literal: true

RSpec.describe Supabase::Storage::Client do
  let(:base_url) { "https://example.supabase.co/storage/v1" }
  let(:default_headers) { { "apikey" => "test-api-key", "Authorization" => "Bearer test-token" } }
  let(:client) { described_class.new(url: base_url, headers: default_headers) }

  # ---------------------------------------------------------------------------
  # BM: Bucket Management
  # ---------------------------------------------------------------------------
  describe "#list_buckets" do
    it "BM-01: lists all buckets" do
      stub_request(:get, "#{base_url}/bucket")
        .to_return(
          status: 200,
          body: '[{"id":"b1","name":"b1","public":false},{"id":"b2","name":"b2","public":true}]',
          headers: { "Content-Type" => "application/json" }
        )

      result = client.list_buckets
      expect(result[:data]).to eq([
                                    { "id" => "b1", "name" => "b1", "public" => false },
                                    { "id" => "b2", "name" => "b2", "public" => true }
                                  ])
      expect(result[:error]).to be_nil
    end

    it "BM-02: lists buckets with options" do
      stub = stub_request(:get, "#{base_url}/bucket")
             .with(body: { limit: 10, offset: 5 }.to_json)
             .to_return(status: 200, body: "[]", headers: { "Content-Type" => "application/json" })

      client.list_buckets(limit: 10, offset: 5)
      expect(stub).to have_been_requested
    end

    it "BM-03: returns error on failure" do
      stub_request(:get, "#{base_url}/bucket")
        .to_return(status: 403, body: '{"message":"Forbidden"}')

      result = client.list_buckets
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
      expect(result[:error].message).to eq("Forbidden")
      expect(result[:error].status).to eq(403)
    end

    it "BM-04: returns unknown error on network failure" do
      stub_request(:get, "#{base_url}/bucket")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      result = client.list_buckets
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageUnknownError)
      expect(result[:error].message).to eq("connection refused")
    end
  end

  describe "#get_bucket" do
    it "BM-05: gets a bucket by ID" do
      stub_request(:get, "#{base_url}/bucket/my-bucket")
        .to_return(
          status: 200,
          body: '{"id":"my-bucket","name":"my-bucket","public":true}',
          headers: { "Content-Type" => "application/json" }
        )

      result = client.get_bucket("my-bucket")
      expect(result[:data]).to eq({ "id" => "my-bucket", "name" => "my-bucket", "public" => true })
      expect(result[:error]).to be_nil
    end

    it "BM-06: returns error when bucket not found" do
      stub_request(:get, "#{base_url}/bucket/missing")
        .to_return(status: 404, body: '{"message":"Bucket not found"}')

      result = client.get_bucket("missing")
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
      expect(result[:error].status).to eq(404)
    end
  end

  describe "#create_bucket" do
    it "BM-07: creates a bucket with defaults" do
      stub = stub_request(:post, "#{base_url}/bucket")
             .with(body: { id: "new-bucket", name: "new-bucket" }.to_json)
             .to_return(status: 200, body: '{"name":"new-bucket"}')

      result = client.create_bucket("new-bucket")
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "name" => "new-bucket" })
      expect(result[:error]).to be_nil
    end

    it "BM-08: creates a bucket with all options" do
      expected_body = {
        id: "public-bucket",
        name: "public-bucket",
        public: true,
        file_size_limit: 5_000_000,
        allowed_mime_types: ["image/png", "image/jpeg"]
      }

      stub = stub_request(:post, "#{base_url}/bucket")
             .with(body: expected_body.to_json)
             .to_return(status: 200, body: '{"name":"public-bucket"}')

      result = client.create_bucket(
        "public-bucket",
        public: true,
        file_size_limit: 5_000_000,
        allowed_mime_types: ["image/png", "image/jpeg"]
      )
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "name" => "public-bucket" })
    end
  end

  describe "#update_bucket" do
    it "BM-09: updates a bucket" do
      stub = stub_request(:put, "#{base_url}/bucket/my-bucket")
             .with(body: { public: true, file_size_limit: 10_000_000 }.to_json)
             .to_return(status: 200, body: '{"message":"Successfully updated"}')

      result = client.update_bucket("my-bucket", public: true, file_size_limit: 10_000_000)
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "message" => "Successfully updated" })
      expect(result[:error]).to be_nil
    end
  end

  describe "#empty_bucket" do
    it "empties a bucket" do
      stub = stub_request(:post, "#{base_url}/bucket/my-bucket/empty")
             .with(body: "{}")
             .to_return(status: 200, body: '{"message":"Successfully emptied"}')

      result = client.empty_bucket("my-bucket")
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "message" => "Successfully emptied" })
    end
  end

  describe "#delete_bucket" do
    it "deletes a bucket" do
      stub = stub_request(:delete, "#{base_url}/bucket/my-bucket")
             .to_return(status: 200, body: '{"message":"Successfully deleted"}')

      result = client.delete_bucket("my-bucket")
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "message" => "Successfully deleted" })
    end
  end
end
