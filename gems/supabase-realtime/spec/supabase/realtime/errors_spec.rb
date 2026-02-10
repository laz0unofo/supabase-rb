# frozen_string_literal: true

RSpec.describe "Realtime Errors" do
  describe Supabase::Realtime::RealtimeError do
    it "is a StandardError" do
      expect(described_class.new).to be_a(StandardError)
    end

    it "has a context attribute" do
      error = described_class.new("msg", context: { key: "val" })
      expect(error.context).to eq({ key: "val" })
      expect(error.message).to eq("msg")
    end
  end

  describe Supabase::Realtime::RealtimeConnectionError do
    it "inherits from RealtimeError" do
      expect(described_class.new).to be_a(Supabase::Realtime::RealtimeError)
    end

    it "has a status attribute" do
      error = described_class.new("connection failed", status: 500)
      expect(error.status).to eq(500)
      expect(error.message).to eq("connection failed")
    end
  end

  describe Supabase::Realtime::RealtimeSubscriptionError do
    it "inherits from RealtimeError" do
      expect(described_class.new).to be_a(Supabase::Realtime::RealtimeError)
    end
  end

  describe Supabase::Realtime::RealtimeApiError do
    it "inherits from RealtimeError" do
      expect(described_class.new).to be_a(Supabase::Realtime::RealtimeError)
    end

    it "has a status attribute" do
      error = described_class.new("api error", status: 403)
      expect(error.status).to eq(403)
    end
  end
end
