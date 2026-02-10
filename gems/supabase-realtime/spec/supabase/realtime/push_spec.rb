# frozen_string_literal: true

RSpec.describe Supabase::Realtime::Push do
  let(:url) { "wss://example.supabase.co/realtime/v1" }
  let(:apikey) { "test-api-key" }
  let(:client) { Supabase::Realtime::Client.new(url, params: { apikey: apikey }) }
  let(:channel) { client.channel("test-room") }

  describe "initialization" do
    it "creates a push with channel and event" do
      push = described_class.new(channel: channel, event: "phx_join")
      expect(push.channel).to eq(channel)
      expect(push.event).to eq("phx_join")
      expect(push.payload).to eq({})
      expect(push.ref).to be_nil
      expect(push.timeout).to eq(10_000)
    end

    it "accepts custom payload" do
      push = described_class.new(channel: channel, event: "msg", payload: { "text" => "hi" })
      expect(push.payload).to eq({ "text" => "hi" })
    end

    it "accepts custom timeout" do
      push = described_class.new(channel: channel, event: "msg", timeout: 5_000)
      expect(push.timeout).to eq(5_000)
    end
  end

  describe "#send_message" do
    it "assigns a ref from the client" do
      allow(client).to receive(:push)

      push = described_class.new(channel: channel, event: "phx_join")
      push.send_message

      expect(push.ref).not_to be_nil
    end

    it "pushes the message through the client" do
      allow(client).to receive(:push)

      push = described_class.new(channel: channel, event: "phx_join", payload: { "key" => "val" })
      channel.instance_variable_set(:@join_ref, "5")
      push.send_message

      expect(client).to have_received(:push).with(
        hash_including(
          "topic" => "realtime:test-room",
          "event" => "phx_join",
          "payload" => { "key" => "val" },
          "join_ref" => "5"
        )
      )
    end

    it "returns self for chaining" do
      allow(client).to receive(:push)

      push = described_class.new(channel: channel, event: "msg")
      result = push.send_message

      expect(result).to eq(push)
    end
  end

  describe "#receive" do
    it "registers a callback for a status" do
      push = described_class.new(channel: channel, event: "phx_join")
      received = nil
      push.receive("ok") { |response| received = response }

      push.trigger("ok", { "data" => "success" })

      expect(received).to eq({ "data" => "success" })
    end

    it "registers callbacks for different statuses" do
      push = described_class.new(channel: channel, event: "phx_join")
      ok_response = nil
      error_response = nil

      push.receive("ok") { |response| ok_response = response }
      push.receive("error") { |response| error_response = response }

      push.trigger("ok", { "data" => "success" })

      expect(ok_response).to eq({ "data" => "success" })
      expect(error_response).to be_nil
    end

    it "triggers immediately if reply already received" do
      push = described_class.new(channel: channel, event: "phx_join")
      push.trigger("ok", { "data" => "done" })

      received = nil
      push.receive("ok") { |response| received = response }

      expect(received).to eq({ "data" => "done" })
    end

    it "returns self for chaining" do
      push = described_class.new(channel: channel, event: "msg")
      result = push.receive("ok") { |_r| nil }
      expect(result).to eq(push)
    end

    it "accepts symbol status" do
      push = described_class.new(channel: channel, event: "phx_join")
      received = nil
      push.receive(:ok) { |response| received = response }

      push.trigger("ok", { "data" => "success" })

      expect(received).to eq({ "data" => "success" })
    end
  end

  describe "#trigger" do
    it "calls all registered callbacks for the status" do
      push = described_class.new(channel: channel, event: "phx_join")
      results = []
      push.receive("ok") { |r| results << [:first, r] }
      push.receive("ok") { |r| results << [:second, r] }

      push.trigger("ok", { "done" => true })

      expect(results.size).to eq(2)
      expect(results[0]).to eq([:first, { "done" => true }])
      expect(results[1]).to eq([:second, { "done" => true }])
    end

    it "does not trigger callbacks for different status" do
      push = described_class.new(channel: channel, event: "phx_join")
      received = nil
      push.receive("ok") { |r| received = r }

      push.trigger("error", { "reason" => "denied" })

      expect(received).to be_nil
    end

    it "stores the reply for late-registered callbacks" do
      push = described_class.new(channel: channel, event: "phx_join")
      push.trigger("ok", { "status" => "ready" })

      received = nil
      push.receive("ok") { |r| received = r }

      expect(received).to eq({ "status" => "ready" })
    end
  end

  describe "ref correlation" do
    it "assigns monotonically increasing refs" do
      allow(client).to receive(:push)

      push1 = described_class.new(channel: channel, event: "msg")
      push2 = described_class.new(channel: channel, event: "msg")

      push1.send_message
      push2.send_message

      expect(push1.ref.to_i).to be < push2.ref.to_i
    end

    it "includes ref in outgoing message" do
      allow(client).to receive(:push)

      push = described_class.new(channel: channel, event: "phx_join")
      push.send_message

      expect(client).to have_received(:push).with(
        hash_including("ref" => push.ref)
      )
    end
  end
end
