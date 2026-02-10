# frozen_string_literal: true

RSpec.describe Supabase::Realtime::Serializer do
  describe ".encode" do
    it "encodes a hash to JSON string" do
      message = { "topic" => "test", "event" => "msg", "payload" => { "body" => "hello" }, "ref" => "1" }
      encoded = described_class.encode(message)
      expect(JSON.parse(encoded)).to eq(message)
    end

    it "encodes an empty hash" do
      expect(described_class.encode({})).to eq("{}")
    end
  end

  describe ".decode" do
    it "decodes a JSON string to hash" do
      raw = '{"topic":"test","event":"msg","payload":{},"ref":"1"}'
      decoded = described_class.decode(raw)
      expect(decoded["topic"]).to eq("test")
      expect(decoded["event"]).to eq("msg")
    end

    it "returns nil for invalid JSON" do
      expect(described_class.decode("not json")).to be_nil
    end

    it "returns nil for empty string" do
      expect(described_class.decode("")).to be_nil
    end
  end
end
