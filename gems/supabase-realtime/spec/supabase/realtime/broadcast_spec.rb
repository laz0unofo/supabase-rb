# frozen_string_literal: true

RSpec.describe "Broadcast" do
  let(:url) { "wss://example.supabase.co/realtime/v1" }
  let(:apikey) { "test-api-key" }
  let(:client) { Supabase::Realtime::Client.new(url, params: { apikey: apikey }) }
  let(:channel) { client.channel("test-room") }

  describe "#on_broadcast" do
    it "registers a broadcast listener" do
      callback = proc { |_payload| }
      channel.on_broadcast("test-event", &callback)
      bindings = channel.instance_variable_get(:@bindings)
      expect(bindings.size).to eq(1)
      expect(bindings.first[:type]).to eq(:broadcast)
      expect(bindings.first[:event]).to eq("test-event")
    end

    it "returns self for chaining" do
      result = channel.on_broadcast("event") { |_p| nil }
      expect(result).to eq(channel)
    end

    it "registers multiple broadcast listeners" do
      channel.on_broadcast("event1") { |_p| nil }
      channel.on_broadcast("event2") { |_p| nil }
      bindings = channel.instance_variable_get(:@bindings)
      broadcast_bindings = bindings.select { |b| b[:type] == :broadcast }
      expect(broadcast_bindings.size).to eq(2)
    end
  end

  describe "broadcast message dispatch" do
    it "dispatches broadcast to matching event listener" do
      received = nil
      channel.on_broadcast("chat") { |payload| received = payload }

      message = {
        "topic" => "realtime:test-room",
        "event" => "broadcast",
        "payload" => { "event" => "chat", "payload" => { "msg" => "hello" } },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to eq({ "msg" => "hello" })
    end

    it "does not dispatch to non-matching event listener" do
      received = nil
      channel.on_broadcast("other") { |payload| received = payload }

      message = {
        "topic" => "realtime:test-room",
        "event" => "broadcast",
        "payload" => { "event" => "chat", "payload" => { "msg" => "hello" } },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to be_nil
    end

    it "dispatches to wildcard listener" do
      received = nil
      channel.on_broadcast("*") { |payload| received = payload }

      message = {
        "topic" => "realtime:test-room",
        "event" => "broadcast",
        "payload" => { "event" => "any-event", "payload" => { "data" => 1 } },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to eq({ "data" => 1 })
    end

    it "dispatches to multiple matching listeners" do
      results = []
      channel.on_broadcast("chat") { |payload| results << [:first, payload] }
      channel.on_broadcast("chat") { |payload| results << [:second, payload] }

      message = {
        "topic" => "realtime:test-room",
        "event" => "broadcast",
        "payload" => { "event" => "chat", "payload" => { "x" => 1 } },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(results.size).to eq(2)
      expect(results[0][0]).to eq(:first)
      expect(results[1][0]).to eq(:second)
    end
  end

  describe "#send_broadcast (WebSocket)" do
    it "sends a WebSocket broadcast message" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("10")
      channel.instance_variable_set(:@join_ref, "5")

      channel.send_broadcast(event: "chat", payload: { text: "hi" })

      expect(client).to have_received(:push).with(
        hash_including(
          "topic" => "realtime:test-room",
          "event" => "broadcast",
          "ref" => "10",
          "join_ref" => "5",
          "payload" => hash_including(
            "event" => "chat",
            "payload" => { text: "hi" },
            "type" => "broadcast"
          )
        )
      )
    end

    it "defaults to WebSocket type" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("1")

      channel.send_broadcast(event: "test", payload: {})

      expect(client).to have_received(:push)
    end
  end

  describe "#send_broadcast (HTTP)" do
    it "sends an HTTP broadcast via Faraday" do
      stub_request(:post, "https://example.supabase.co/api/broadcast")
        .to_return(status: 200, body: "{}")

      channel.send_broadcast(event: "chat", payload: { text: "hi" }, type: :http)

      expect(
        a_request(:post, "https://example.supabase.co/api/broadcast")
          .with do |req|
            body = JSON.parse(req.body)
            body["messages"].is_a?(Array) &&
              body["messages"][0]["topic"] == "realtime:test-room" &&
              body["messages"][0]["event"] == "chat" &&
              body["messages"][0]["payload"] == { "text" => "hi" }
          end
      ).to have_been_made
    end

    it "includes apikey and authorization headers" do
      stub_request(:post, "https://example.supabase.co/api/broadcast")
        .to_return(status: 200, body: "{}")

      channel.send_broadcast(event: "test", payload: {}, type: :http)

      expect(WebMock).to have_requested(:post, "https://example.supabase.co/api/broadcast")
        .with(headers: {
                "Content-Type" => "application/json",
                "Apikey" => apikey,
                "Authorization" => "Bearer #{apikey}"
              })
    end

    it "uses access_token in authorization when available" do
      client.set_auth("user-token")
      ch = client.channel("room")

      stub_request(:post, "https://example.supabase.co/api/broadcast")
        .to_return(status: 200, body: "{}")

      ch.send_broadcast(event: "test", payload: {}, type: :http)

      expect(WebMock).to have_requested(:post, "https://example.supabase.co/api/broadcast")
        .with(headers: { "Authorization" => "Bearer user-token" })
    end
  end

  describe "self-broadcast config" do
    it "includes broadcast config in join payload" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("1")

      ch = client.channel("room", config: { "broadcast" => { "self" => true } })
      ch.subscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "payload" => hash_including(
            "config" => hash_including(
              "broadcast" => { "self" => true }
            )
          )
        )
      )
    end

    it "includes default empty broadcast config" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("1")

      ch = client.channel("room")
      ch.subscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "payload" => hash_including(
            "config" => hash_including("broadcast" => {})
          )
        )
      )
    end
  end
end
