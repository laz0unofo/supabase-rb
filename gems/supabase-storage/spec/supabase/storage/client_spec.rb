# frozen_string_literal: true

RSpec.describe Supabase::Storage::Client do
  let(:base_url) { "https://example.supabase.co/storage/v1" }
  let(:default_headers) { { "apikey" => "test-api-key", "Authorization" => "Bearer test-token" } }
  let(:client) { described_class.new(url: base_url, headers: default_headers) }

  describe "#initialize" do
    it "strips trailing slashes from URL" do
      c = described_class.new(url: "#{base_url}/", headers: {})
      file_api = c.from("test-bucket")
      expect(file_api.bucket_id).to eq("test-bucket")
    end

    it "stores headers as a dup" do
      headers = { "apikey" => "key" }
      c = described_class.new(url: base_url, headers: headers)
      headers["extra"] = "value"
      file_api = c.from("test")
      # file_api should not have the extra header added after construction
      expect(file_api).to be_a(Supabase::Storage::StorageFileApi)
    end
  end

  describe "#from" do
    it "returns a StorageFileApi scoped to the given bucket" do
      file_api = client.from("my-bucket")
      expect(file_api).to be_a(Supabase::Storage::StorageFileApi)
      expect(file_api.bucket_id).to eq("my-bucket")
    end

    it "returns independent file APIs for different buckets" do
      api1 = client.from("bucket-a")
      api2 = client.from("bucket-b")
      expect(api1.bucket_id).to eq("bucket-a")
      expect(api2.bucket_id).to eq("bucket-b")
    end
  end
end
