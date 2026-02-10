# frozen_string_literal: true

RSpec.describe Supabase::Storage::StorageFileApi do
  let(:base_url) { "https://example.supabase.co/storage/v1" }
  let(:bucket_id) { "test-bucket" }
  let(:default_headers) { { "apikey" => "test-api-key", "Authorization" => "Bearer test-token" } }
  let(:file_api) do
    described_class.new(url: base_url, bucket_id: bucket_id, headers: default_headers)
  end

  # ---------------------------------------------------------------------------
  # UL: Upload
  # ---------------------------------------------------------------------------
  describe "#upload" do
    it "UL-01: uploads a string body" do
      stub = stub_request(:post, "#{base_url}/object/#{bucket_id}/folder/file.txt")
             .with(
               body: "hello world",
               headers: {
                 "cache-control" => "max-age=3600",
                 "content-type" => "application/octet-stream"
               }
             )
             .to_return(
               status: 200,
               body: '{"id":"abc","path":"folder/file.txt","fullPath":"test-bucket/folder/file.txt"}'
             )

      result = file_api.upload("folder/file.txt", "hello world")
      expect(stub).to have_been_requested
      expect(result[:data]["id"]).to eq("abc")
      expect(result[:error]).to be_nil
    end

    it "UL-02: uploads an IO body" do
      io = StringIO.new("binary data")
      stub = stub_request(:post, "#{base_url}/object/#{bucket_id}/file.bin")
             .with(body: "binary data")
             .to_return(status: 200, body: '{"id":"def","path":"file.bin","fullPath":"test-bucket/file.bin"}')

      result = file_api.upload("file.bin", io)
      expect(stub).to have_been_requested
      expect(result[:data]["id"]).to eq("def")
    end

    it "UL-03: sets custom cache control" do
      stub = stub_request(:post, "#{base_url}/object/#{bucket_id}/file.txt")
             .with(headers: { "cache-control" => "max-age=7200" })
             .to_return(status: 200, body: '{"id":"1"}')

      file_api.upload("file.txt", "data", cache_control: "7200")
      expect(stub).to have_been_requested
    end

    it "UL-04: sets custom content type" do
      stub = stub_request(:post, "#{base_url}/object/#{bucket_id}/image.png")
             .with(headers: { "content-type" => "image/png" })
             .to_return(status: 200, body: '{"id":"2"}')

      file_api.upload("image.png", "png-data", content_type: "image/png")
      expect(stub).to have_been_requested
    end

    it "UL-05: sets upsert header when upsert is true" do
      stub = stub_request(:post, "#{base_url}/object/#{bucket_id}/file.txt")
             .with(headers: { "x-upsert" => "true" })
             .to_return(status: 200, body: '{"id":"3"}')

      file_api.upload("file.txt", "data", upsert: true)
      expect(stub).to have_been_requested
    end

    it "UL-06: does not set upsert header when upsert is false" do
      stub_request(:post, "#{base_url}/object/#{bucket_id}/file.txt")
        .to_return(status: 200, body: '{"id":"4"}')

      file_api.upload("file.txt", "data")

      expect(
        a_request(:post, "#{base_url}/object/#{bucket_id}/file.txt")
          .with { |req| !req.headers.key?("X-Upsert") }
      ).to have_been_made
    end

    it "UL-07: sets metadata header" do
      metadata = { "owner" => "user1" }
      stub = stub_request(:post, "#{base_url}/object/#{bucket_id}/file.txt")
             .with(headers: { "x-metadata" => JSON.generate(metadata) })
             .to_return(status: 200, body: '{"id":"5"}')

      file_api.upload("file.txt", "data", metadata: metadata)
      expect(stub).to have_been_requested
    end

    it "UL-08: normalizes path with leading/trailing slashes" do
      stub = stub_request(:post, "#{base_url}/object/#{bucket_id}/folder/file.txt")
             .to_return(status: 200, body: '{"id":"6"}')

      file_api.upload("/folder/file.txt/", "data")
      expect(stub).to have_been_requested
    end

    it "UL-09: collapses consecutive slashes in path" do
      stub = stub_request(:post, "#{base_url}/object/#{bucket_id}/folder/sub/file.txt")
             .to_return(status: 200, body: '{"id":"7"}')

      file_api.upload("folder//sub///file.txt", "data")
      expect(stub).to have_been_requested
    end

    it "UL-10: returns error on HTTP failure" do
      stub_request(:post, "#{base_url}/object/#{bucket_id}/file.txt")
        .to_return(status: 400, body: '{"message":"Invalid file"}')

      result = file_api.upload("file.txt", "data")
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
      expect(result[:error].message).to eq("Invalid file")
      expect(result[:error].status).to eq(400)
    end

    it "UL-11: returns unknown error on network failure" do
      stub_request(:post, "#{base_url}/object/#{bucket_id}/file.txt")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      result = file_api.upload("file.txt", "data")
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageUnknownError)
    end
  end

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------
  describe "#update" do
    it "UL-12: updates a file via PUT" do
      stub = stub_request(:put, "#{base_url}/object/#{bucket_id}/file.txt")
             .with(
               body: "updated content",
               headers: { "content-type" => "text/plain" }
             )
             .to_return(status: 200, body: '{"id":"8","path":"file.txt"}')

      result = file_api.update("file.txt", "updated content", content_type: "text/plain")
      expect(stub).to have_been_requested
      expect(result[:data]["id"]).to eq("8")
      expect(result[:error]).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # DL: Download
  # ---------------------------------------------------------------------------
  describe "#download" do
    it "DL-01: downloads a file" do
      stub_request(:get, "#{base_url}/object/#{bucket_id}/folder/file.txt")
        .to_return(status: 200, body: "file contents")

      result = file_api.download("folder/file.txt")
      expect(result[:data]).to eq("file contents")
      expect(result[:error]).to be_nil
    end

    it "DL-02: returns raw binary body" do
      binary = "\x89PNG\r\n\x1a\n"
      stub_request(:get, "#{base_url}/object/#{bucket_id}/image.png")
        .to_return(status: 200, body: binary)

      result = file_api.download("image.png")
      expect(result[:data]).to eq(binary)
    end

    it "DL-03: uses render/image/authenticated path when transform provided" do
      stub = stub_request(:get, "#{base_url}/render/image/authenticated/#{bucket_id}/photo.jpg?width=200&height=100")
             .to_return(status: 200, body: "transformed-image")

      result = file_api.download("photo.jpg", transform: { width: 200, height: 100 })
      expect(stub).to have_been_requested
      expect(result[:data]).to eq("transformed-image")
    end

    it "DL-04: returns error on HTTP failure" do
      stub_request(:get, "#{base_url}/object/#{bucket_id}/missing.txt")
        .to_return(status: 404, body: '{"message":"Object not found"}')

      result = file_api.download("missing.txt")
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageApiError)
      expect(result[:error].status).to eq(404)
    end

    it "DL-05: returns unknown error on network failure" do
      stub_request(:get, "#{base_url}/object/#{bucket_id}/file.txt")
        .to_raise(Faraday::TimeoutError.new("request timed out"))

      result = file_api.download("file.txt")
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageUnknownError)
    end

    it "DL-06: normalizes path for downloads" do
      stub = stub_request(:get, "#{base_url}/object/#{bucket_id}/folder/file.txt")
             .to_return(status: 200, body: "data")

      file_api.download("/folder//file.txt/")
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # FO: File Operations (move, copy, remove, info, exists?)
  # ---------------------------------------------------------------------------
  describe "#move" do
    it "FO-01: moves a file within the same bucket" do
      stub = stub_request(:post, "#{base_url}/object/move")
             .with(body: {
               bucketId: bucket_id,
               sourceKey: "old/path.txt",
               destinationBucket: bucket_id,
               destinationKey: "new/path.txt"
             }.to_json)
             .to_return(status: 200, body: '{"message":"Successfully moved"}')

      result = file_api.move("old/path.txt", "new/path.txt")
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "message" => "Successfully moved" })
      expect(result[:error]).to be_nil
    end

    it "FO-02: moves a file to a different bucket" do
      stub = stub_request(:post, "#{base_url}/object/move")
             .with(body: {
               bucketId: bucket_id,
               sourceKey: "file.txt",
               destinationBucket: "other-bucket",
               destinationKey: "file.txt"
             }.to_json)
             .to_return(status: 200, body: '{"message":"Successfully moved"}')

      result = file_api.move("file.txt", "file.txt", destination_bucket: "other-bucket")
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "message" => "Successfully moved" })
    end
  end

  describe "#copy" do
    it "FO-03: copies a file within the same bucket" do
      stub = stub_request(:post, "#{base_url}/object/copy")
             .with(body: {
               bucketId: bucket_id,
               sourceKey: "original.txt",
               destinationBucket: bucket_id,
               destinationKey: "copy.txt"
             }.to_json)
             .to_return(status: 200, body: '{"key":"test-bucket/copy.txt"}')

      result = file_api.copy("original.txt", "copy.txt")
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "key" => "test-bucket/copy.txt" })
      expect(result[:error]).to be_nil
    end

    it "FO-04: copies a file to a different bucket" do
      stub = stub_request(:post, "#{base_url}/object/copy")
             .with(body: {
               bucketId: bucket_id,
               sourceKey: "file.txt",
               destinationBucket: "archive",
               destinationKey: "backup.txt"
             }.to_json)
             .to_return(status: 200, body: '{"key":"archive/backup.txt"}')

      result = file_api.copy("file.txt", "backup.txt", destination_bucket: "archive")
      expect(stub).to have_been_requested
      expect(result[:data]).to eq({ "key" => "archive/backup.txt" })
    end
  end

  describe "#remove" do
    it "FO-05: removes multiple files" do
      stub = stub_request(:delete, "#{base_url}/object/#{bucket_id}")
             .with(body: { prefixes: ["file1.txt", "folder/file2.txt"] }.to_json)
             .to_return(
               status: 200,
               body: '[{"name":"file1.txt"},{"name":"folder/file2.txt"}]'
             )

      result = file_api.remove(["file1.txt", "folder/file2.txt"])
      expect(stub).to have_been_requested
      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to eq(2)
      expect(result[:error]).to be_nil
    end
  end

  describe "#info" do
    it "FO-06: gets file metadata" do
      stub = stub_request(:get, "#{base_url}/object/info/#{bucket_id}/folder/file.txt")
             .to_return(
               status: 200,
               body: '{"name":"file.txt","size":1024,"content_type":"text/plain"}'
             )

      result = file_api.info("folder/file.txt")
      expect(stub).to have_been_requested
      expect(result[:data]["name"]).to eq("file.txt")
      expect(result[:data]["size"]).to eq(1024)
      expect(result[:error]).to be_nil
    end
  end

  describe "#exists?" do
    it "FO-07: returns true when file exists" do
      stub_request(:head, "#{base_url}/object/#{bucket_id}/file.txt")
        .to_return(status: 200)

      result = file_api.exists?("file.txt")
      expect(result[:data]).to be true
      expect(result[:error]).to be_nil
    end

    it "returns false when file does not exist" do
      stub_request(:head, "#{base_url}/object/#{bucket_id}/missing.txt")
        .to_return(status: 404)

      result = file_api.exists?("missing.txt")
      expect(result[:data]).to be false
      expect(result[:error]).to be_nil
    end

    it "returns unknown error on network failure" do
      stub_request(:head, "#{base_url}/object/#{bucket_id}/file.txt")
        .to_raise(Faraday::ConnectionFailed.new("refused"))

      result = file_api.exists?("file.txt")
      expect(result[:data]).to be_nil
      expect(result[:error]).to be_a(Supabase::Storage::StorageUnknownError)
    end
  end
end
