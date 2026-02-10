# frozen_string_literal: true

RSpec.describe Supabase::Realtime::RealtimeChannel do
  let(:url) { "wss://example.supabase.co/realtime/v1" }
  let(:apikey) { "test-api-key" }
  let(:client) { Supabase::Realtime::Client.new(url, params: { apikey: apikey }) }
  let(:channel) { client.channel("test-room") }

  describe "initialization" do
    it "sets topic with realtime: prefix" do
      expect(channel.topic).to eq("realtime:test-room")
    end

    it "starts in :closed state" do
      expect(channel.state).to eq(:closed)
    end

    it "references the client" do
      expect(channel.client).to eq(client)
    end

    it "has nil join_ref initially" do
      expect(channel.join_ref).to be_nil
    end
  end

  describe "#subscribe" do
    it "sets state to :joining" do
      channel.subscribe
      expect(channel.state).to eq(:joining)
    end

    it "sets join_ref" do
      channel.subscribe
      expect(channel.join_ref).not_to be_nil
    end

    it "pushes a phx_join message" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("1")

      channel.subscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "topic" => "realtime:test-room",
          "event" => "phx_join",
          "ref" => "1",
          "join_ref" => "1"
        )
      )
    end

    it "includes access_token in join payload" do
      client.set_auth("my-token")
      ch = client.channel("room")
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("2")

      ch.subscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "payload" => hash_including("access_token" => "my-token")
        )
      )
    end

    it "returns self for chaining" do
      result = channel.subscribe
      expect(result).to eq(channel)
    end
  end

  describe "#unsubscribe" do
    it "sets state to :closed" do
      channel.instance_variable_set(:@state, :joined)
      channel.unsubscribe
      expect(channel.state).to eq(:closed)
    end

    it "pushes a phx_leave message" do
      channel.instance_variable_set(:@state, :joined)
      channel.instance_variable_set(:@join_ref, "5")
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("6")

      channel.unsubscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "topic" => "realtime:test-room",
          "event" => "phx_leave",
          "join_ref" => "5"
        )
      )
    end
  end

  describe "#rejoin" do
    it "does nothing if state is :closed" do
      allow(client).to receive(:push)
      channel.rejoin
      expect(client).not_to have_received(:push)
    end

    it "re-sends phx_join if state was :joined" do
      channel.instance_variable_set(:@state, :joined)
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("10")

      channel.rejoin

      expect(channel.state).to eq(:joining)
      expect(client).to have_received(:push).with(
        hash_including("event" => "phx_join")
      )
    end
  end

  describe "#handle_message" do
    it "handles phx_reply with ok status (join success)" do
      channel.instance_variable_set(:@state, :joining)
      channel.instance_variable_set(:@join_ref, "1")

      callback_args = nil
      channel.instance_variable_set(:@subscribe_callback, lambda { |status, error|
        callback_args = [status, error]
      })

      message = {
        "topic" => "realtime:test-room",
        "event" => "phx_reply",
        "payload" => { "status" => "ok", "response" => {} },
        "ref" => "1"
      }
      channel.handle_message(message)

      expect(channel.state).to eq(:joined)
      expect(callback_args).to eq([:subscribed, nil])
    end

    it "handles phx_reply with error status (join failure)" do
      channel.instance_variable_set(:@state, :joining)
      channel.instance_variable_set(:@join_ref, "1")

      callback_args = nil
      channel.instance_variable_set(:@subscribe_callback, lambda { |status, error|
        callback_args = [status, error]
      })

      message = {
        "topic" => "realtime:test-room",
        "event" => "phx_reply",
        "payload" => { "status" => "error", "response" => { "message" => "unauthorized" } },
        "ref" => "1"
      }
      channel.handle_message(message)

      expect(channel.state).to eq(:closed)
      expect(callback_args[0]).to eq(:channel_error)
      expect(callback_args[1]).to be_a(Supabase::Realtime::RealtimeSubscriptionError)
    end

    it "handles phx_close" do
      channel.instance_variable_set(:@state, :joined)
      message = {
        "topic" => "realtime:test-room",
        "event" => "phx_close",
        "payload" => {},
        "ref" => nil
      }
      channel.handle_message(message)
      expect(channel.state).to eq(:closed)
    end

    it "handles phx_error" do
      channel.instance_variable_set(:@state, :joined)

      callback_args = nil
      channel.instance_variable_set(:@subscribe_callback, lambda { |status, error|
        callback_args = [status, error]
      })

      message = {
        "topic" => "realtime:test-room",
        "event" => "phx_error",
        "payload" => { "message" => "server error" },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(channel.state).to eq(:closed)
      expect(callback_args[0]).to eq(:channel_error)
    end

    it "ignores replies for non-join refs" do
      channel.instance_variable_set(:@state, :joining)
      channel.instance_variable_set(:@join_ref, "1")

      message = {
        "topic" => "realtime:test-room",
        "event" => "phx_reply",
        "payload" => { "status" => "ok", "response" => {} },
        "ref" => "999"
      }
      channel.handle_message(message)

      expect(channel.state).to eq(:joining)
    end
  end

  describe "#update_access_token" do
    it "updates the channel access token" do
      channel.update_access_token("new-token")
      expect(channel.instance_variable_get(:@access_token)).to eq("new-token")
    end
  end
end
