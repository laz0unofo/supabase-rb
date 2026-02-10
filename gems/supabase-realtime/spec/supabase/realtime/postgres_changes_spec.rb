# frozen_string_literal: true

RSpec.describe "PostgreSQL Changes" do
  let(:url) { "wss://example.supabase.co/realtime/v1" }
  let(:apikey) { "test-api-key" }
  let(:client) { Supabase::Realtime::Client.new(url, params: { apikey: apikey }) }
  let(:channel) { client.channel("test-room") }

  describe "#on_postgres_changes" do
    it "registers a postgres_changes binding" do
      channel.on_postgres_changes(event: :insert, schema: "public", table: "users") { |_p| nil }

      bindings = channel.instance_variable_get(:@bindings)
      pg_bindings = bindings.select { |b| b[:type] == :postgres_changes }
      expect(pg_bindings.size).to eq(1)
      expect(pg_bindings.first[:event]).to eq("INSERT")
      expect(pg_bindings.first[:schema]).to eq("public")
      expect(pg_bindings.first[:table]).to eq("users")
    end

    it "returns self for chaining" do
      result = channel.on_postgres_changes(event: :insert) { |_p| nil }
      expect(result).to eq(channel)
    end

    it "normalizes :insert to INSERT" do
      channel.on_postgres_changes(event: :insert) { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding[:event]).to eq("INSERT")
    end

    it "normalizes :update to UPDATE" do
      channel.on_postgres_changes(event: :update) { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding[:event]).to eq("UPDATE")
    end

    it "normalizes :delete to DELETE" do
      channel.on_postgres_changes(event: :delete) { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding[:event]).to eq("DELETE")
    end

    it "normalizes :all to *" do
      channel.on_postgres_changes(event: :all) { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding[:event]).to eq("*")
    end

    it "normalizes :* to *" do
      channel.on_postgres_changes(event: :*) { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding[:event]).to eq("*")
    end

    it "defaults schema to public" do
      channel.on_postgres_changes(event: :insert) { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding[:schema]).to eq("public")
    end

    it "accepts custom schema" do
      channel.on_postgres_changes(event: :insert, schema: "private") { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding[:schema]).to eq("private")
    end

    it "omits table when nil" do
      channel.on_postgres_changes(event: :insert) { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding).not_to have_key(:table)
    end

    it "includes filter when provided" do
      channel.on_postgres_changes(event: :update, table: "users", filter: "id=eq.1") { |_p| nil }
      binding = channel.instance_variable_get(:@bindings).first
      expect(binding[:filter]).to eq("id=eq.1")
    end

    it "registers multiple bindings" do
      channel.on_postgres_changes(event: :insert, table: "users") { |_p| nil }
      channel.on_postgres_changes(event: :delete, table: "posts") { |_p| nil }
      bindings = channel.instance_variable_get(:@bindings)
      pg_bindings = bindings.select { |b| b[:type] == :postgres_changes }
      expect(pg_bindings.size).to eq(2)
    end
  end

  describe "postgres_changes in join config" do
    it "includes postgres_changes bindings in join payload" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("1")

      channel.on_postgres_changes(event: :insert, schema: "public", table: "users") { |_p| nil }
      channel.subscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "payload" => hash_including(
            "config" => hash_including(
              "postgres_changes" => [
                hash_including("event" => "INSERT", "schema" => "public", "table" => "users")
              ]
            )
          )
        )
      )
    end

    it "includes filter in join config" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("1")

      channel.on_postgres_changes(
        event: :update, table: "users", filter: "id=eq.1"
      ) { |_p| nil }
      channel.subscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "payload" => hash_including(
            "config" => hash_including(
              "postgres_changes" => [
                hash_including("event" => "UPDATE", "table" => "users", "filter" => "id=eq.1")
              ]
            )
          )
        )
      )
    end

    it "includes multiple postgres_changes in join config" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("1")

      channel.on_postgres_changes(event: :insert, table: "users") { |_p| nil }
      channel.on_postgres_changes(event: :delete, table: "posts") { |_p| nil }
      channel.subscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "payload" => hash_including(
            "config" => hash_including(
              "postgres_changes" => contain_exactly(
                hash_including("event" => "INSERT", "table" => "users"),
                hash_including("event" => "DELETE", "table" => "posts")
              )
            )
          )
        )
      )
    end

    it "sends empty postgres_changes array when no CDC bindings" do
      allow(client).to receive(:push)
      allow(client).to receive(:make_ref).and_return("1")

      channel.subscribe

      expect(client).to have_received(:push).with(
        hash_including(
          "payload" => hash_including(
            "config" => hash_including("postgres_changes" => [])
          )
        )
      )
    end
  end

  describe "postgres_changes message dispatch" do
    it "dispatches INSERT event to matching listener" do
      received = nil
      channel.on_postgres_changes(event: :insert, schema: "public", table: "users") do |payload|
        received = payload
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "data" => {
            "type" => "INSERT",
            "schema" => "public",
            "table" => "users",
            "record" => { "id" => 1, "name" => "Alice" }
          }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to include("type" => "INSERT", "table" => "users")
    end

    it "dispatches UPDATE event to matching listener" do
      received = nil
      channel.on_postgres_changes(event: :update, schema: "public", table: "users") do |payload|
        received = payload
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "data" => {
            "type" => "UPDATE",
            "schema" => "public",
            "table" => "users",
            "record" => { "id" => 1, "name" => "Alice Updated" },
            "old_record" => { "id" => 1, "name" => "Alice" }
          }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to include("type" => "UPDATE", "table" => "users")
    end

    it "dispatches DELETE event to matching listener" do
      received = nil
      channel.on_postgres_changes(event: :delete, schema: "public", table: "users") do |payload|
        received = payload
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "data" => {
            "type" => "DELETE",
            "schema" => "public",
            "table" => "users",
            "old_record" => { "id" => 1, "name" => "Alice" }
          }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to include("type" => "DELETE", "table" => "users")
    end

    it "dispatches all events to wildcard (*) listener" do
      results = []
      channel.on_postgres_changes(event: :all, schema: "public", table: "users") do |payload|
        results << payload["type"]
      end

      %w[INSERT UPDATE DELETE].each do |event_type|
        message = {
          "topic" => "realtime:test-room",
          "event" => "postgres_changes",
          "payload" => {
            "data" => {
              "type" => event_type,
              "schema" => "public",
              "table" => "users",
              "record" => {}
            }
          },
          "ref" => nil
        }
        channel.handle_message(message)
      end

      expect(results).to eq(%w[INSERT UPDATE DELETE])
    end

    it "does not dispatch to listener for different table" do
      received = nil
      channel.on_postgres_changes(event: :insert, schema: "public", table: "posts") do |payload|
        received = payload
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "data" => {
            "type" => "INSERT",
            "schema" => "public",
            "table" => "users",
            "record" => {}
          }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to be_nil
    end

    it "does not dispatch to listener for different schema" do
      received = nil
      channel.on_postgres_changes(event: :insert, schema: "private", table: "users") do |payload|
        received = payload
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "data" => {
            "type" => "INSERT",
            "schema" => "public",
            "table" => "users",
            "record" => {}
          }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to be_nil
    end

    it "does not dispatch to listener for different event type" do
      received = nil
      channel.on_postgres_changes(event: :insert, schema: "public", table: "users") do |payload|
        received = payload
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "data" => {
            "type" => "DELETE",
            "schema" => "public",
            "table" => "users",
            "record" => {}
          }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to be_nil
    end

    it "dispatches to listener without table (schema-wide)" do
      received = nil
      channel.on_postgres_changes(event: :insert, schema: "public") do |payload|
        received = payload
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "data" => {
            "type" => "INSERT",
            "schema" => "public",
            "table" => "any_table",
            "record" => { "id" => 1 }
          }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to include("type" => "INSERT")
    end

    it "handles payload without data wrapper" do
      received = nil
      channel.on_postgres_changes(event: :insert, schema: "public", table: "users") do |payload|
        received = payload
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "type" => "INSERT",
          "schema" => "public",
          "table" => "users",
          "record" => { "id" => 1 }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(received).to include("type" => "INSERT")
    end

    it "dispatches to multiple matching listeners" do
      results = []
      channel.on_postgres_changes(event: :all, schema: "public") { |_p| results << :wildcard }
      channel.on_postgres_changes(event: :insert, schema: "public", table: "users") do |_p|
        results << :specific
      end

      message = {
        "topic" => "realtime:test-room",
        "event" => "postgres_changes",
        "payload" => {
          "data" => {
            "type" => "INSERT",
            "schema" => "public",
            "table" => "users",
            "record" => {}
          }
        },
        "ref" => nil
      }
      channel.handle_message(message)

      expect(results).to eq(%i[wildcard specific])
    end
  end
end
