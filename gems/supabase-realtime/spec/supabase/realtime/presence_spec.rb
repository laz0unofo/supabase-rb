# frozen_string_literal: true

RSpec.describe "Presence" do
  let(:url) { "wss://example.supabase.co/realtime/v1" }
  let(:apikey) { "test-api-key" }
  let(:client) { Supabase::Realtime::Client.new(url, params: { apikey: apikey }) }
  let(:channel) { client.channel("test-room") }
  let(:presence) { channel.presence }

  describe Supabase::Realtime::Presence do
    describe "initialization" do
      it "starts with empty state" do
        expect(presence.state).to eq({})
      end
    end

    describe "#sync" do
      it "replaces state with new state" do
        new_state = { "user1" => { "online_at" => "2024-01-01" } }
        presence.sync(new_state, new_state, {})
        expect(presence.state).to eq(new_state)
      end

      it "notifies sync callbacks" do
        synced = nil
        presence.on_sync { |state| synced = state }

        new_state = { "user1" => { "name" => "Alice" } }
        presence.sync(new_state, new_state, {})

        expect(synced).to eq(new_state)
      end

      it "notifies join callbacks when joins present" do
        joined = nil
        presence.on_join { |joins| joined = joins }

        joins = { "user1" => { "name" => "Alice" } }
        presence.sync(joins, joins, {})

        expect(joined).to eq(joins)
      end

      it "notifies leave callbacks when leaves present" do
        left = nil
        presence.on_leave { |leaves| left = leaves }

        leaves = { "user2" => { "name" => "Bob" } }
        presence.sync({}, {}, leaves)

        expect(left).to eq(leaves)
      end

      it "does not notify join callbacks when joins empty" do
        called = false
        presence.on_join { |_joins| called = true }

        presence.sync({ "user1" => {} }, {}, {})

        expect(called).to be(false)
      end

      it "does not notify leave callbacks when leaves empty" do
        called = false
        presence.on_leave { |_leaves| called = true }

        presence.sync({ "user1" => {} }, { "user1" => {} }, {})

        expect(called).to be(false)
      end
    end

    describe "#sync_diff" do
      it "applies joins to state" do
        joins = { "user1" => { "name" => "Alice" } }
        presence.sync_diff(joins, {})
        expect(presence.state).to eq({ "user1" => { "name" => "Alice" } })
      end

      it "applies leaves to state" do
        presence.sync_diff({ "user1" => { "name" => "Alice" } }, {})
        presence.sync_diff({}, { "user1" => { "name" => "Alice" } })
        expect(presence.state).to eq({})
      end

      it "handles simultaneous joins and leaves" do
        presence.sync_diff({ "user1" => { "name" => "Alice" } }, {})

        presence.sync_diff(
          { "user2" => { "name" => "Bob" } },
          { "user1" => { "name" => "Alice" } }
        )

        expect(presence.state).to eq({ "user2" => { "name" => "Bob" } })
      end

      it "notifies join callbacks on diff" do
        joined = nil
        presence.on_join { |joins| joined = joins }

        presence.sync_diff({ "user1" => { "name" => "Alice" } }, {})

        expect(joined).to eq({ "user1" => { "name" => "Alice" } })
      end

      it "notifies leave callbacks on diff" do
        presence.sync_diff({ "user1" => { "name" => "Alice" } }, {})

        left = nil
        presence.on_leave { |leaves| left = leaves }

        presence.sync_diff({}, { "user1" => { "name" => "Alice" } })

        expect(left).to eq({ "user1" => { "name" => "Alice" } })
      end

      it "notifies sync callbacks on diff" do
        synced = nil
        presence.on_sync { |state| synced = state }

        presence.sync_diff({ "user1" => { "name" => "Alice" } }, {})

        expect(synced).to eq({ "user1" => { "name" => "Alice" } })
      end

      it "swallows errors in callbacks" do
        presence.on_join { |_joins| raise "boom" }
        expect { presence.sync_diff({ "user1" => {} }, {}) }.not_to raise_error
      end
    end

    describe "multiple callbacks" do
      it "notifies all registered join callbacks" do
        results = []
        presence.on_join { |_j| results << :first }
        presence.on_join { |_j| results << :second }

        presence.sync_diff({ "user1" => {} }, {})

        expect(results).to eq(%i[first second])
      end

      it "notifies all registered leave callbacks" do
        results = []
        presence.on_leave { |_l| results << :first }
        presence.on_leave { |_l| results << :second }

        presence.sync_diff({ "user1" => {} }, {})
        presence.sync_diff({}, { "user1" => {} })

        expect(results).to eq(%i[first second])
      end

      it "notifies all registered sync callbacks" do
        results = []
        presence.on_sync { |_s| results << :first }
        presence.on_sync { |_s| results << :second }

        presence.sync_diff({}, {})

        expect(results).to eq(%i[first second])
      end
    end
  end

  describe "channel presence integration" do
    describe "#on_presence" do
      it "registers sync callback" do
        synced = nil
        channel.on_presence(:sync) { |state| synced = state }

        presence.sync_diff({ "user1" => {} }, {})

        expect(synced).to eq({ "user1" => {} })
      end

      it "registers join callback" do
        joined = nil
        channel.on_presence(:join) { |joins| joined = joins }

        presence.sync_diff({ "user1" => { "name" => "Alice" } }, {})

        expect(joined).to eq({ "user1" => { "name" => "Alice" } })
      end

      it "registers leave callback" do
        left = nil
        channel.on_presence(:leave) { |leaves| left = leaves }

        presence.sync_diff({ "user1" => {} }, {})
        presence.sync_diff({}, { "user1" => {} })

        expect(left).to eq({ "user1" => {} })
      end

      it "returns self for chaining" do
        result = channel.on_presence(:sync) { |_s| nil }
        expect(result).to eq(channel)
      end
    end

    describe "#track" do
      it "sends a presence track message" do
        allow(client).to receive(:push)
        allow(client).to receive(:make_ref).and_return("7")
        channel.instance_variable_set(:@join_ref, "3")

        channel.track({ "user" => "Alice", "status" => "online" })

        expect(client).to have_received(:push).with(
          hash_including(
            "topic" => "realtime:test-room",
            "event" => "presence",
            "ref" => "7",
            "join_ref" => "3",
            "payload" => hash_including(
              "event" => "track",
              "type" => "presence",
              "payload" => { "user" => "Alice", "status" => "online" }
            )
          )
        )
      end
    end

    describe "#untrack" do
      it "sends a presence untrack message" do
        allow(client).to receive(:push)
        allow(client).to receive(:make_ref).and_return("8")
        channel.instance_variable_set(:@join_ref, "3")

        channel.untrack

        expect(client).to have_received(:push).with(
          hash_including(
            "topic" => "realtime:test-room",
            "event" => "presence",
            "ref" => "8",
            "join_ref" => "3",
            "payload" => hash_including(
              "event" => "untrack",
              "type" => "presence"
            )
          )
        )
      end
    end

    describe "presence_diff message handling" do
      it "updates presence state on presence_diff" do
        message = {
          "topic" => "realtime:test-room",
          "event" => "presence_diff",
          "payload" => {
            "joins" => { "user1" => { "name" => "Alice" } },
            "leaves" => {}
          },
          "ref" => nil
        }
        channel.handle_message(message)

        expect(presence.state).to eq({ "user1" => { "name" => "Alice" } })
      end

      it "handles presence_diff with leaves" do
        presence.sync_diff({ "user1" => { "name" => "Alice" } }, {})

        message = {
          "topic" => "realtime:test-room",
          "event" => "presence_diff",
          "payload" => {
            "joins" => {},
            "leaves" => { "user1" => { "name" => "Alice" } }
          },
          "ref" => nil
        }
        channel.handle_message(message)

        expect(presence.state).to eq({})
      end
    end

    describe "presence_state message handling" do
      it "syncs full presence state" do
        message = {
          "topic" => "realtime:test-room",
          "event" => "presence_state",
          "payload" => {
            "user1" => { "name" => "Alice" },
            "user2" => { "name" => "Bob" }
          },
          "ref" => nil
        }
        channel.handle_message(message)

        expect(presence.state).to include("user1", "user2")
      end

      it "strips type key from presence_state payload" do
        message = {
          "topic" => "realtime:test-room",
          "event" => "presence_state",
          "payload" => {
            "type" => "presence_state",
            "user1" => { "name" => "Alice" }
          },
          "ref" => nil
        }
        channel.handle_message(message)

        expect(presence.state).not_to have_key("type")
        expect(presence.state).to have_key("user1")
      end
    end
  end
end
