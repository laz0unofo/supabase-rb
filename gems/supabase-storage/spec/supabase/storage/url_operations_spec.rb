# frozen_string_literal: true

RSpec.describe Supabase::Storage::StorageFileApi do
  let(:base_url) { "https://example.supabase.co/storage/v1" }
  let(:bucket_id) { "test-bucket" }
  let(:default_headers) { { "apikey" => "test-api-key", "Authorization" => "Bearer test-token" } }
  let(:file_api) do
    described_class.new(url: base_url, bucket_id: bucket_id, headers: default_headers)
  end

  # ---------------------------------------------------------------------------
  # SU: Signed URLs
  # ---------------------------------------------------------------------------
  describe "#create_signed_url" do
    it "SU-01: creates a signed URL" do
      stub_request(:post, "#{base_url}/object/sign/#{bucket_id}/folder/file.txt")
        .with(body: { expiresIn: 3600 }.to_json)
        .to_return(
          status: 200,
          body: '{"signedURL":"/object/sign/test-bucket/folder/file.txt?token=abc123"}'
        )

      result = file_api.create_signed_url("folder/file.txt", 3600)
      expect(result[:data][:signed_url]).to eq(
        "#{base_url}/object/sign/test-bucket/folder/file.txt?token=abc123"
      )
      expect(result[:error]).to be_nil
    end

    it "SU-02: creates a signed URL with download param (boolean)" do
      stub_request(:post, "#{base_url}/object/sign/#{bucket_id}/file.txt")
        .to_return(
          status: 200,
          body: '{"signedURL":"/object/sign/test-bucket/file.txt?token=abc"}'
        )

      result = file_api.create_signed_url("file.txt", 3600, download: true)
      expect(result[:data][:signed_url]).to include("&download=")
    end

    it "SU-03: creates a signed URL with download param (filename)" do
      stub_request(:post, "#{base_url}/object/sign/#{bucket_id}/file.txt")
        .to_return(
          status: 200,
          body: '{"signedURL":"/object/sign/test-bucket/file.txt?token=abc"}'
        )

      result = file_api.create_signed_url("file.txt", 3600, download: "custom.txt")
      expect(result[:data][:signed_url]).to include("&download=custom.txt")
    end

    it "SU-04: creates a signed URL with transform options" do
      stub = stub_request(:post, "#{base_url}/object/sign/#{bucket_id}/image.jpg")
             .with(body: { expiresIn: 3600, transform: { width: 200, height: 100 } }.to_json)
             .to_return(
               status: 200,
               body: '{"signedURL":"/render/image/sign/test-bucket/image.jpg?token=abc"}'
             )

      result = file_api.create_signed_url("image.jpg", 3600, transform: { width: 200, height: 100 })
      expect(stub).to have_been_requested
      expect(result[:error]).to be_nil
    end

    it "SU-05: returns error on failure" do
      stub_request(:post, "#{base_url}/object/sign/#{bucket_id}/file.txt")
        .to_return(status: 400, body: '{"message":"Invalid path"}')

      result = file_api.create_signed_url("file.txt", 3600)
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
    end
  end

  describe "#create_signed_urls" do
    it "SU-06: creates batch signed URLs" do
      stub_request(:post, "#{base_url}/object/sign")
        .with(body: {
          expiresIn: 3600,
          paths: ["test-bucket/file1.txt", "test-bucket/file2.txt"]
        }.to_json)
        .to_return(
          status: 200,
          body: [
            { "signedURL" => "/object/sign/test-bucket/file1.txt?token=a", "path" => "file1.txt", "error" => nil },
            { "signedURL" => "/object/sign/test-bucket/file2.txt?token=b", "path" => "file2.txt", "error" => nil }
          ].to_json
        )

      result = file_api.create_signed_urls(["file1.txt", "file2.txt"], 3600)
      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to eq(2)
      expect(result[:data][0][:signed_url]).to include("token=a")
      expect(result[:data][1][:signed_url]).to include("token=b")
      expect(result[:error]).to be_nil
    end

    it "SU-07: creates batch signed URLs with download" do
      stub_request(:post, "#{base_url}/object/sign")
        .to_return(
          status: 200,
          body: [
            { "signedURL" => "/object/sign/test-bucket/file1.txt?token=a", "path" => "file1.txt", "error" => nil }
          ].to_json
        )

      result = file_api.create_signed_urls(["file1.txt"], 3600, download: true)
      expect(result[:data][0][:signed_url]).to include("&download=")
    end
  end

  # ---------------------------------------------------------------------------
  # Signed Upload URLs
  # ---------------------------------------------------------------------------
  describe "#create_signed_upload_url" do
    it "creates a signed upload URL" do
      stub_request(:post, "#{base_url}/object/upload/sign/#{bucket_id}/folder/file.txt")
        .to_return(
          status: 200,
          body: '{"url":"/object/upload/sign/test-bucket/folder/file.txt?token=xyz","token":"xyz"}'
        )

      result = file_api.create_signed_upload_url("folder/file.txt")
      expect(result[:data][:signed_url]).to eq(
        "#{base_url}/object/upload/sign/test-bucket/folder/file.txt?token=xyz"
      )
      expect(result[:data][:token]).to eq("xyz")
      expect(result[:data][:path]).to eq("folder/file.txt")
      expect(result[:error]).to be_nil
    end

    it "sets x-upsert header when upsert is true" do
      stub = stub_request(:post, "#{base_url}/object/upload/sign/#{bucket_id}/file.txt")
             .with(headers: { "x-upsert" => "true" })
             .to_return(status: 200, body: '{"url":"/upload/sign/test-bucket/file.txt?token=t","token":"t"}')

      file_api.create_signed_upload_url("file.txt", upsert: true)
      expect(stub).to have_been_requested
    end
  end

  describe "#upload_to_signed_url" do
    it "uploads to a signed URL" do
      token = "my-upload-token"
      stub = stub_request(:put, "#{base_url}/object/upload/sign/#{bucket_id}/file.txt?token=#{token}")
             .with(
               body: "file data",
               headers: {
                 "cache-control" => "max-age=3600",
                 "content-type" => "application/octet-stream",
                 "x-upsert" => "false"
               }
             )
             .to_return(status: 200, body: '{"key":"test-bucket/file.txt"}')

      result = file_api.upload_to_signed_url("file.txt", token, "file data")
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "key" => "test-bucket/file.txt" })
      expect(result[:error]).to be_nil
    end

    it "uploads with upsert flag" do
      stub = stub_request(:put, %r{/object/upload/sign/#{bucket_id}/file\.txt\?token=})
             .with(headers: { "x-upsert" => "true" })
             .to_return(status: 200, body: '{"key":"test-bucket/file.txt"}')

      file_api.upload_to_signed_url("file.txt", "tok", "data", upsert: true)
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # PU: Public URLs
  # ---------------------------------------------------------------------------
  describe "#get_public_url" do
    it "PU-01: generates a public URL" do
      result = file_api.get_public_url("folder/file.txt")
      expect(result[:data][:public_url]).to eq(
        "#{base_url}/object/public/#{bucket_id}/folder/file.txt"
      )
      expect(result[:error]).to be_nil
    end

    it "PU-02: generates a public URL with download (boolean)" do
      result = file_api.get_public_url("file.txt", download: true)
      expect(result[:data][:public_url]).to eq(
        "#{base_url}/object/public/#{bucket_id}/file.txt?download="
      )
    end

    it "PU-03: generates a public URL with download (filename)" do
      result = file_api.get_public_url("file.txt", download: "custom.txt")
      expect(result[:data][:public_url]).to eq(
        "#{base_url}/object/public/#{bucket_id}/file.txt?download=custom.txt"
      )
    end

    it "PU-04: generates a public URL with image transforms" do
      result = file_api.get_public_url("image.jpg", transform: { width: 200, height: 100, quality: 80 })
      url = result[:data][:public_url]
      expect(url).to start_with("#{base_url}/render/image/public/#{bucket_id}/image.jpg?")
      expect(url).to include("width=200")
      expect(url).to include("height=100")
      expect(url).to include("quality=80")
    end

    it "normalizes path for public URLs" do
      result = file_api.get_public_url("/folder//file.txt/")
      expect(result[:data][:public_url]).to eq(
        "#{base_url}/object/public/#{bucket_id}/folder/file.txt"
      )
    end

    it "generates public URL with both transform and download" do
      result = file_api.get_public_url("img.jpg", download: true, transform: { width: 50 })
      url = result[:data][:public_url]
      expect(url).to start_with("#{base_url}/render/image/public/#{bucket_id}/img.jpg?")
      expect(url).to include("width=50")
      expect(url).to include("download=")
    end
  end

  # ---------------------------------------------------------------------------
  # FL: File Listing
  # ---------------------------------------------------------------------------
  describe "#list" do
    it "FL-01: lists files with defaults" do
      stub = stub_request(:post, "#{base_url}/object/list/#{bucket_id}")
             .with(body: {
               prefix: "",
               limit: 100,
               offset: 0,
               sortBy: { column: "name", order: "asc" }
             }.to_json)
             .to_return(
               status: 200,
               body: '[{"name":"file1.txt","id":"1"},{"name":"file2.txt","id":"2"}]'
             )

      result = file_api.list
      expect(stub).to have_been_requested
      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to eq(2)
      expect(result[:error]).to be_nil
    end

    it "FL-02: lists files in a specific path" do
      stub = stub_request(:post, "#{base_url}/object/list/#{bucket_id}")
             .with(body: hash_including("prefix" => "folder/sub"))
             .to_return(status: 200, body: "[]")

      file_api.list("folder/sub")
      expect(stub).to have_been_requested
    end

    it "FL-03: lists files with custom limit and offset" do
      stub = stub_request(:post, "#{base_url}/object/list/#{bucket_id}")
             .with(body: hash_including("limit" => 10, "offset" => 20))
             .to_return(status: 200, body: "[]")

      file_api.list(nil, limit: 10, offset: 20)
      expect(stub).to have_been_requested
    end

    it "FL-04: lists files with custom sort" do
      stub = stub_request(:post, "#{base_url}/object/list/#{bucket_id}")
             .with(body: hash_including("sortBy" => { "column" => "created_at", "order" => "desc" }))
             .to_return(status: 200, body: "[]")

      file_api.list(nil, sort_by: { column: "created_at", order: "desc" })
      expect(stub).to have_been_requested
    end

    it "FL-05: lists files with search" do
      stub = stub_request(:post, "#{base_url}/object/list/#{bucket_id}")
             .with(body: hash_including("search" => "photo"))
             .to_return(status: 200, body: "[]")

      file_api.list(nil, search: "photo")
      expect(stub).to have_been_requested
    end

    it "FL-06: returns error on listing failure" do
      stub_request(:post, "#{base_url}/object/list/#{bucket_id}")
        .to_return(status: 500, body: '{"message":"Internal error"}')

      result = file_api.list
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
      expect(result[:error].status).to eq(500)
    end
  end
end
