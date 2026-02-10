# frozen_string_literal: true

RSpec.describe "Storage Error Hierarchy" do
  # ---------------------------------------------------------------------------
  # EH: Error Handling
  # ---------------------------------------------------------------------------
  describe Supabase::Storage::StorageError do
    it "EH-01: is a StandardError" do
      expect(Supabase::Storage::StorageError.new).to be_a(StandardError)
    end

    it "stores message and context" do
      error = Supabase::Storage::StorageError.new("something failed", context: { detail: "info" })
      expect(error.message).to eq("something failed")
      expect(error.context).to eq({ detail: "info" })
    end

    it "defaults context to nil" do
      error = Supabase::Storage::StorageError.new("oops")
      expect(error.context).to be_nil
    end
  end

  describe Supabase::Storage::StorageApiError do
    it "EH-02: is a StorageError" do
      expect(Supabase::Storage::StorageApiError.new).to be_a(Supabase::Storage::StorageError)
    end

    it "stores message, status, and context" do
      error = Supabase::Storage::StorageApiError.new("Not found", status: 404, context: "resp")
      expect(error.message).to eq("Not found")
      expect(error.status).to eq(404)
      expect(error.context).to eq("resp")
    end

    it "defaults status to nil" do
      error = Supabase::Storage::StorageApiError.new("err")
      expect(error.status).to be_nil
    end
  end

  describe Supabase::Storage::StorageUnknownError do
    it "EH-03: is a StorageError" do
      expect(Supabase::Storage::StorageUnknownError.new).to be_a(Supabase::Storage::StorageError)
    end

    it "stores message, status, and context" do
      error = Supabase::Storage::StorageUnknownError.new("timeout", status: 0, context: "ex")
      expect(error.message).to eq("timeout")
      expect(error.status).to eq(0)
      expect(error.context).to eq("ex")
    end
  end

  describe "EH-04: error classification in Client" do
    let(:base_url) { "https://example.supabase.co/storage/v1" }
    let(:client) { Supabase::Storage::Client.new(url: base_url, headers: {}) }

    it "returns StorageApiError for JSON error responses" do
      stub_request(:get, "#{base_url}/bucket/bad")
        .to_return(status: 400, body: '{"message":"Bad request"}')

      result = client.get_bucket("bad")
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
      expect(result[:error].message).to eq("Bad request")
      expect(result[:error].status).to eq(400)
    end

    it "returns StorageApiError for non-JSON error responses" do
      stub_request(:get, "#{base_url}/bucket/bad")
        .to_return(status: 500, body: "Internal Server Error")

      result = client.get_bucket("bad")
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
      expect(result[:error].message).to eq("Internal Server Error")
      expect(result[:error].status).to eq(500)
    end

    it "extracts error from 'error' JSON key" do
      stub_request(:get, "#{base_url}/bucket/bad")
        .to_return(status: 403, body: '{"error":"Access denied"}')

      result = client.get_bucket("bad")
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
      expect(result[:error].message).to eq("Access denied")
    end

    it "returns StorageUnknownError for network failures" do
      stub_request(:get, "#{base_url}/bucket/test")
        .to_raise(Faraday::ConnectionFailed.new("connection reset"))

      result = client.get_bucket("test")
      expect(result[:error]).to be_a(Supabase::Storage::StorageUnknownError)
      expect(result[:error].message).to eq("connection reset")
    end

    it "returns StorageUnknownError for timeout errors" do
      stub_request(:get, "#{base_url}/bucket/test")
        .to_raise(Faraday::TimeoutError.new("request timed out"))

      result = client.get_bucket("test")
      expect(result[:error]).to be_a(Supabase::Storage::StorageUnknownError)
      expect(result[:error].message).to eq("request timed out")
    end
  end

  describe "path normalization" do
    let(:base_url) { "https://example.supabase.co/storage/v1" }
    let(:file_api) do
      Supabase::Storage::StorageFileApi.new(url: base_url, bucket_id: "bucket", headers: {})
    end

    it "strips leading slashes" do
      stub = stub_request(:get, "#{base_url}/object/info/bucket/file.txt")
             .to_return(status: 200, body: '{"name":"file.txt"}')

      file_api.info("/file.txt")
      expect(stub).to have_been_requested
    end

    it "strips trailing slashes" do
      stub = stub_request(:get, "#{base_url}/object/info/bucket/file.txt")
             .to_return(status: 200, body: '{"name":"file.txt"}')

      file_api.info("file.txt/")
      expect(stub).to have_been_requested
    end

    it "collapses consecutive slashes" do
      stub = stub_request(:get, "#{base_url}/object/info/bucket/a/b/c.txt")
             .to_return(status: 200, body: '{"name":"c.txt"}')

      file_api.info("a///b//c.txt")
      expect(stub).to have_been_requested
    end

    it "handles empty path" do
      stub = stub_request(:get, "#{base_url}/object/info/bucket/")
             .to_return(status: 200, body: "{}")

      file_api.info("")
      expect(stub).to have_been_requested
    end
  end

  describe "image transform query params" do
    let(:base_url) { "https://example.supabase.co/storage/v1" }
    let(:file_api) do
      Supabase::Storage::StorageFileApi.new(url: base_url, bucket_id: "bucket", headers: {})
    end

    it "generates width param" do
      result = file_api.get_public_url("img.jpg", transform: { width: 300 })
      expect(result[:data][:public_url]).to include("width=300")
    end

    it "generates height param" do
      result = file_api.get_public_url("img.jpg", transform: { height: 200 })
      expect(result[:data][:public_url]).to include("height=200")
    end

    it "generates resize param" do
      result = file_api.get_public_url("img.jpg", transform: { resize: "cover" })
      expect(result[:data][:public_url]).to include("resize=cover")
    end

    it "generates quality param" do
      result = file_api.get_public_url("img.jpg", transform: { quality: 80 })
      expect(result[:data][:public_url]).to include("quality=80")
    end

    it "generates format param" do
      result = file_api.get_public_url("img.jpg", transform: { format: "webp" })
      expect(result[:data][:public_url]).to include("format=webp")
    end

    it "generates multiple transform params" do
      result = file_api.get_public_url("img.jpg", transform: { width: 200, height: 100, quality: 90 })
      url = result[:data][:public_url]
      expect(url).to include("width=200")
      expect(url).to include("height=100")
      expect(url).to include("quality=90")
    end

    it "uses render/image/public path for transforms" do
      result = file_api.get_public_url("img.jpg", transform: { width: 100 })
      expect(result[:data][:public_url]).to start_with("#{base_url}/render/image/public/bucket/img.jpg")
    end

    it "uses render/image/authenticated path for download transforms" do
      stub = stub_request(:get, %r{/render/image/authenticated/bucket/img\.jpg\?width=100})
             .to_return(status: 200, body: "image-data")

      file_api.download("img.jpg", transform: { width: 100 })
      expect(stub).to have_been_requested
    end
  end
end
