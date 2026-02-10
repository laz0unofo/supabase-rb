# frozen_string_literal: true

RSpec.describe Supabase::Realtime::Client do
  let(:url) { "wss://example.supabase.co/realtime/v1" }
  let(:apikey) { "test-api-key" }
  let(:params) { { apikey: apikey } }
  let(:client) { described_class.new(url, params: params) }

  describe "constructor" do
    it "creates a client with required params" do
      expect(client.state).to eq(:closed)
      expect(client.channels).to eq([])
      expect(client.access_token).to be_nil
    end

    it "validates params[:apikey] is present" do
      expect { described_class.new(url, params: {}) }.to raise_error(
        ArgumentError, "params[:apikey] is required"
      )
    end

    it "accepts string key for apikey" do
      c = described_class.new(url, params: { "apikey" => apikey })
      expect(c.state).to eq(:closed)
    end

    it "accepts optional access_token" do
      c = described_class.new(url, params: params, access_token: "my-token")
      expect(c.access_token).to eq("my-token")
    end

    it "accepts optional timeout" do
      c = described_class.new(url, params: params, timeout: 5_000)
      expect(c).to be_a(described_class)
    end

    it "accepts optional heartbeat_interval_ms" do
      c = described_class.new(url, params: params, heartbeat_interval_ms: 15_000)
      expect(c).to be_a(described_class)
    end

    it "accepts optional reconnect_after_ms callback" do
      cb = ->(attempt) { attempt * 1_000 }
      c = described_class.new(url, params: params, reconnect_after_ms: cb)
      expect(c).to be_a(described_class)
    end

    it "accepts optional logger" do
      logger = instance_double("Logger")
      c = described_class.new(url, params: params, logger: logger)
      expect(c).to be_a(described_class)
    end
  end

  describe "endpoint URL" do
    it "appends /socket/websocket to the URL" do
      expect(client.endpoint_url.path).to eq("/realtime/v1/socket/websocket")
    end

    it "preserves the host" do
      expect(client.endpoint_url.host).to eq("example.supabase.co")
    end

    it "handles URL with trailing slash" do
      c = described_class.new("wss://example.supabase.co/realtime/v1/", params: params)
      expect(c.endpoint_url.path).to eq("/realtime/v1/socket/websocket")
    end
  end

  describe "HTTP broadcast URL" do
    it "derives HTTP broadcast endpoint from wss URL" do
      expect(client.http_broadcast_url).to eq("https://example.supabase.co/api/broadcast")
    end

    it "derives HTTP broadcast endpoint from ws URL" do
      c = described_class.new("ws://localhost:4000/realtime/v1", params: params)
      expect(c.http_broadcast_url).to eq("http://localhost:4000/api/broadcast")
    end

    it "strips /socket/websocket suffix" do
      c = described_class.new("wss://example.supabase.co/socket/websocket", params: params)
      expect(c.http_broadcast_url).to eq("https://example.supabase.co/api/broadcast")
    end
  end

  describe "#connect" do
    it "changes state to :connecting and calls do_connect" do
      allow(WebSocket::Client::Simple).to receive(:connect).and_return(double("ws"))
      client.connect
      expect(client.state).to eq(:connecting).or eq(:open)
    end

    it "does not reconnect when already connecting" do
      allow(WebSocket::Client::Simple).to receive(:connect).and_return(double("ws"))
      client.connect
      expect(WebSocket::Client::Simple).to have_received(:connect).once
      client.connect
      expect(WebSocket::Client::Simple).to have_received(:connect).once
    end
  end

  describe "#disconnect" do
    it "sets state to closed" do
      # Simulate an open connection
      client.instance_variable_set(:@state, :open)
      ws_mock = instance_double("WebSocket::Client::Simple::Client", close: nil)
      client.instance_variable_set(:@ws, ws_mock)

      client.disconnect
      expect(client.state).to eq(:closed)
    end

    it "does nothing when already closed" do
      client.disconnect
      expect(client.state).to eq(:closed)
    end
  end

  describe "#channel" do
    it "creates a channel with realtime: topic prefix" do
      channel = client.channel("test-room")
      expect(channel.topic).to eq("realtime:test-room")
    end

    it "adds channel to channels list" do
      client.channel("room1")
      client.channel("room2")
      expect(client.channels.size).to eq(2)
    end

    it "returns a RealtimeChannel" do
      channel = client.channel("test")
      expect(channel).to be_a(Supabase::Realtime::RealtimeChannel)
    end

    it "passes config to channel" do
      channel = client.channel("test", config: { broadcast: { self: true } })
      expect(channel).to be_a(Supabase::Realtime::RealtimeChannel)
    end
  end

  describe "#set_auth" do
    it "updates the access token" do
      client.set_auth("new-token")
      expect(client.access_token).to eq("new-token")
    end

    it "updates access token on all channels" do
      ch1 = client.channel("room1")
      ch2 = client.channel("room2")

      allow(ch1).to receive(:update_access_token)
      allow(ch2).to receive(:update_access_token)

      client.set_auth("new-token")
      expect(ch1).to have_received(:update_access_token).with("new-token")
      expect(ch2).to have_received(:update_access_token).with("new-token")
    end

    it "sets nil token" do
      client.set_auth("token")
      client.set_auth(nil)
      expect(client.access_token).to be_nil
    end
  end

  describe "#remove_channel" do
    it "removes a channel from the list" do
      channel = client.channel("test")
      client.remove_channel(channel)
      expect(client.channels).to be_empty
    end

    it "unsubscribes a joined channel before removing" do
      channel = client.channel("test")
      channel.instance_variable_set(:@state, :joined)
      allow(channel).to receive(:unsubscribe).and_return(channel)

      client.remove_channel(channel)
      expect(channel).to have_received(:unsubscribe)
    end
  end

  describe "#remove_all_channels" do
    it "removes all channels" do
      client.channel("room1")
      client.channel("room2")
      client.remove_all_channels
      expect(client.channels).to be_empty
    end
  end

  describe "#get_channels" do
    it "returns a copy of channels" do
      client.channel("test")
      channels = client.get_channels
      channels.clear
      expect(client.channels.size).to eq(1)
    end
  end

  describe "#make_ref" do
    it "returns monotonically increasing string refs" do
      ref1 = client.make_ref
      ref2 = client.make_ref
      ref3 = client.make_ref
      expect(ref1).to eq("1")
      expect(ref2).to eq("2")
      expect(ref3).to eq("3")
    end

    it "is thread-safe" do
      refs = []
      threads = 10.times.map do
        Thread.new { refs << client.make_ref }
      end
      threads.each(&:join)
      expect(refs.uniq.size).to eq(10)
    end
  end

  describe "#push (send buffer)" do
    it "buffers messages when not connected" do
      message = { "topic" => "test", "event" => "msg", "payload" => {}, "ref" => "1" }
      client.push(message)
      buffer = client.instance_variable_get(:@send_buffer)
      expect(buffer.size).to eq(1)
      expect(JSON.parse(buffer.first)["topic"]).to eq("test")
    end

    it "sends directly when connected" do
      ws_mock = instance_double("WebSocket::Client::Simple::Client")
      allow(ws_mock).to receive(:send)
      client.instance_variable_set(:@state, :open)
      client.instance_variable_set(:@ws, ws_mock)

      message = { "topic" => "test", "event" => "msg", "payload" => {}, "ref" => "1" }
      client.push(message)

      expect(ws_mock).to have_received(:send).with(JSON.generate(message))
      expect(client.instance_variable_get(:@send_buffer)).to be_empty
    end
  end

  describe "#log" do
    it "logs with [Realtime] prefix when logger present" do
      logger = instance_double("Logger")
      allow(logger).to receive(:info)
      c = described_class.new(url, params: params, logger: logger)
      c.log(:info, "test message")
      expect(logger).to have_received(:info).with("[Realtime] test message")
    end

    it "does nothing without a logger" do
      expect { client.log(:info, "test") }.not_to raise_error
    end
  end

  describe "state machine" do
    it "starts in :closed state" do
      expect(client.state).to eq(:closed)
    end

    it "defines valid states" do
      expect(described_class::STATES).to eq(%i[closed connecting open closing])
    end
  end

  describe "message routing" do
    it "routes messages to channels by topic" do
      channel = client.channel("test")
      allow(channel).to receive(:handle_message)

      message = {
        "topic" => "realtime:test",
        "event" => "broadcast",
        "payload" => { "data" => "hello" },
        "ref" => nil
      }
      client.send(:handle_message, message)

      expect(channel).to have_received(:handle_message).with(message)
    end

    it "does not route to channels with different topic" do
      channel = client.channel("other")
      allow(channel).to receive(:handle_message)

      message = {
        "topic" => "realtime:test",
        "event" => "broadcast",
        "payload" => {},
        "ref" => nil
      }
      client.send(:handle_message, message)

      expect(channel).not_to have_received(:handle_message)
    end

    it "routes heartbeat replies to heartbeat handler" do
      client.instance_variable_set(:@pending_heartbeat_ref, "5")

      message = {
        "topic" => "phoenix",
        "event" => "phx_reply",
        "payload" => { "status" => "ok" },
        "ref" => "5"
      }
      client.send(:handle_message, message)

      expect(client.instance_variable_get(:@pending_heartbeat_ref)).to be_nil
    end
  end

  describe "send buffer flush" do
    it "flushes buffered messages on connection open" do
      msg1 = { "topic" => "t1", "event" => "e1", "payload" => {}, "ref" => "1" }
      msg2 = { "topic" => "t2", "event" => "e2", "payload" => {}, "ref" => "2" }
      client.push(msg1)
      client.push(msg2)

      ws_mock = instance_double("WebSocket::Client::Simple::Client")
      allow(ws_mock).to receive(:send)
      client.instance_variable_set(:@ws, ws_mock)

      client.send(:flush_send_buffer)

      expect(ws_mock).to have_received(:send).twice
      expect(client.instance_variable_get(:@send_buffer)).to be_empty
    end
  end

  describe "heartbeat" do
    it "sends heartbeat message with phoenix topic" do
      ws_mock = instance_double("WebSocket::Client::Simple::Client")
      allow(ws_mock).to receive(:send)
      client.instance_variable_set(:@state, :open)
      client.instance_variable_set(:@ws, ws_mock)

      client.send(:send_heartbeat)

      expect(ws_mock).to have_received(:send) do |raw|
        msg = JSON.parse(raw)
        expect(msg["topic"]).to eq("phoenix")
        expect(msg["event"]).to eq("heartbeat")
        expect(msg["payload"]).to eq({})
        expect(msg["ref"]).to be_a(String)
      end
    end

    it "sets pending heartbeat ref" do
      ws_mock = instance_double("WebSocket::Client::Simple::Client")
      allow(ws_mock).to receive(:send)
      client.instance_variable_set(:@state, :open)
      client.instance_variable_set(:@ws, ws_mock)

      client.send(:send_heartbeat)

      expect(client.instance_variable_get(:@pending_heartbeat_ref)).not_to be_nil
    end

    it "triggers reconnect on missed heartbeat" do
      client.instance_variable_set(:@pending_heartbeat_ref, "old-ref")
      allow(client).to receive(:close_websocket)
      allow(client).to receive(:reconnect)

      client.send(:send_heartbeat)

      expect(client).to have_received(:reconnect)
      expect(client.instance_variable_get(:@pending_heartbeat_ref)).to be_nil
    end

    it "clears pending ref on heartbeat reply" do
      client.instance_variable_set(:@pending_heartbeat_ref, "10")
      client.send(:handle_heartbeat_reply, "10")
      expect(client.instance_variable_get(:@pending_heartbeat_ref)).to be_nil
    end

    it "does not clear ref on mismatched reply" do
      client.instance_variable_set(:@pending_heartbeat_ref, "10")
      client.send(:handle_heartbeat_reply, "99")
      expect(client.instance_variable_get(:@pending_heartbeat_ref)).to eq("10")
    end
  end

  describe "reconnection" do
    it "uses default backoff delays" do
      expect(client.send(:reconnect_delay_ms, 0)).to eq(1_000)
      expect(client.send(:reconnect_delay_ms, 1)).to eq(2_000)
      expect(client.send(:reconnect_delay_ms, 2)).to eq(5_000)
      expect(client.send(:reconnect_delay_ms, 3)).to eq(10_000)
    end

    it "caps at the last backoff value" do
      expect(client.send(:reconnect_delay_ms, 10)).to eq(10_000)
      expect(client.send(:reconnect_delay_ms, 100)).to eq(10_000)
    end

    it "uses custom reconnect_after_ms callback" do
      custom = ->(attempt) { (attempt + 1) * 500 }
      c = described_class.new(url, params: params, reconnect_after_ms: custom)
      expect(c.send(:reconnect_delay_ms, 0)).to eq(500)
      expect(c.send(:reconnect_delay_ms, 4)).to eq(2_500)
    end

    it "resets reconnect attempt counter" do
      client.instance_variable_set(:@reconnect_attempt, 5)
      client.send(:reset_reconnect)
      expect(client.instance_variable_get(:@reconnect_attempt)).to eq(0)
    end
  end

  describe "rejoin channels on reconnect" do
    it "rejoins channels that were joined" do
      ch = client.channel("test")
      ch.instance_variable_set(:@state, :joined)
      allow(ch).to receive(:rejoin)

      client.send(:rejoin_channels)
      expect(ch).to have_received(:rejoin)
    end

    it "rejoins channels that were joining" do
      ch = client.channel("test")
      ch.instance_variable_set(:@state, :joining)
      allow(ch).to receive(:rejoin)

      client.send(:rejoin_channels)
      expect(ch).to have_received(:rejoin)
    end

    it "does not rejoin closed channels" do
      ch = client.channel("test")
      allow(ch).to receive(:rejoin)

      client.send(:rejoin_channels)
      expect(ch).not_to have_received(:rejoin)
    end
  end

  describe "WebSocket URL construction" do
    it "includes apikey and vsn query params" do
      ws_url = client.send(:build_ws_url)
      uri = URI.parse(ws_url)
      query = URI.decode_www_form(uri.query).to_h
      expect(query["apikey"]).to eq(apikey)
      expect(query["vsn"]).to eq("1.0.0")
    end
  end
end
