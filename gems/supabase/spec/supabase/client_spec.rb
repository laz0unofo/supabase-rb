# frozen_string_literal: true

RSpec.describe Supabase::Client do
  let(:url) { "https://myproject.supabase.co" }
  let(:key) { "my-api-key-12345" }

  # Stub all sub-client constructors to prevent real initialization
  let(:auth_client) { instance_double(Supabase::Auth::Client) }
  let(:postgrest_client) { instance_double(Supabase::PostgREST::Client) }
  let(:realtime_client) { instance_double(Supabase::Realtime::Client) }
  let(:storage_client) { instance_double(Supabase::Storage::Client) }
  let(:subscription) { double("Subscription", id: "sub-1") }

  before do
    allow(Supabase::Auth::Client).to receive(:new).and_return(auth_client)
    allow(Supabase::PostgREST::Client).to receive(:new).and_return(postgrest_client)
    allow(Supabase::Realtime::Client).to receive(:new).and_return(realtime_client)
    allow(Supabase::Storage::Client).to receive(:new).and_return(storage_client)
    allow(auth_client).to receive(:on_auth_state_change).and_return(subscription)
    allow(auth_client).to receive(:get_session).and_return({ session: nil })
    allow(realtime_client).to receive(:set_auth)
  end

  # ---- CV: Constructor Validation Tests ----
  describe "constructor validation" do
    it "CV-01: raises ArgumentError when url is nil" do
      expect { described_class.new(nil, key) }.to raise_error(ArgumentError, /supabaseUrl is required/)
    end

    it "CV-02: raises ArgumentError when url is empty string" do
      expect { described_class.new("", key) }.to raise_error(ArgumentError, /supabaseUrl is required/)
    end

    it "CV-03: raises ArgumentError when url is whitespace only" do
      expect { described_class.new("   ", key) }.to raise_error(ArgumentError, /supabaseUrl is required/)
    end

    it "CV-04: raises ArgumentError for non-HTTP URL" do
      expect { described_class.new("ftp://example.com", key) }.to raise_error(ArgumentError, /must be a valid URL/)
    end

    it "CV-05: raises ArgumentError for malformed URL" do
      expect do
        described_class.new("not a url at all ://???", key)
      end.to raise_error(ArgumentError, /must be a valid URL/)
    end

    it "CV-06: raises ArgumentError when key is nil" do
      expect { described_class.new(url, nil) }.to raise_error(ArgumentError, /supabaseKey is required/)
    end

    it "CV-07: raises ArgumentError when key is empty string" do
      expect { described_class.new(url, "") }.to raise_error(ArgumentError, /supabaseKey is required/)
    end

    it "CV-08: raises ArgumentError when key is whitespace only" do
      expect { described_class.new(url, "   ") }.to raise_error(ArgumentError, /supabaseKey is required/)
    end

    it "CV-09: accepts valid HTTPS URL" do
      expect { described_class.new(url, key) }.not_to raise_error
    end

    it "CV-10: accepts valid HTTP URL" do
      expect { described_class.new("http://localhost:54321", key) }.not_to raise_error
    end
  end

  # ---- UC: URL Construction Tests ----
  describe "URL construction" do
    it "UC-01: derives service URLs from base URL" do
      described_class.new(url, key)

      expect(Supabase::Auth::Client).to have_received(:new).with(
        hash_including(url: "#{url}/auth/v1")
      )
      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(url: "#{url}/rest/v1")
      )
      expect(Supabase::Storage::Client).to have_received(:new).with(
        hash_including(url: "#{url}/storage/v1")
      )
    end

    it "UC-02: derives Realtime URL with wss scheme" do
      described_class.new(url, key)

      expect(Supabase::Realtime::Client).to have_received(:new).with(
        "wss://myproject.supabase.co/realtime/v1",
        hash_including(:params)
      )
    end

    it "UC-03: derives HTTP Realtime URL with ws scheme for HTTP base" do
      described_class.new("http://localhost:54321", key)

      expect(Supabase::Realtime::Client).to have_received(:new).with(
        "ws://localhost:54321/realtime/v1",
        hash_including(:params)
      )
    end
  end

  # ---- SK: Storage Key Derivation Tests ----
  describe "storage key derivation" do
    it "SK-01: derives storage key from hostname first part" do
      described_class.new(url, key)

      expect(Supabase::Auth::Client).to have_received(:new).with(
        hash_including(storage_key: "sb-myproject-auth-token")
      )
    end

    it "SK-02: derives storage key from localhost" do
      described_class.new("http://localhost:54321", key)

      expect(Supabase::Auth::Client).to have_received(:new).with(
        hash_including(storage_key: "sb-localhost-auth-token")
      )
    end

    it "SK-03: derives storage key from IP-based hostname" do
      described_class.new("http://127.0.0.1:54321", key)

      expect(Supabase::Auth::Client).to have_received(:new).with(
        hash_including(storage_key: "sb-127-auth-token")
      )
    end
  end

  # ---- AM: Auth Mode Tests ----
  describe "auth modes" do
    it "AM-01: initializes Auth client in session-based mode (default)" do
      described_class.new(url, key)

      expect(Supabase::Auth::Client).to have_received(:new)
      expect(auth_client).to have_received(:on_auth_state_change)
    end

    it "AM-02: registers auth state change listener in session mode" do
      described_class.new(url, key)

      expect(auth_client).to have_received(:on_auth_state_change)
    end

    it "AM-03: skips Auth client in third-party auth mode" do
      callback = -> { "third-party-token" }
      described_class.new(url, key, access_token: callback)

      expect(Supabase::Auth::Client).not_to have_received(:new)
    end

    it "AM-04: raises AuthNotAvailableError when accessing auth in third-party mode" do
      callback = -> { "third-party-token" }
      client = described_class.new(url, key, access_token: callback)

      expect { client.auth }.to raise_error(Supabase::AuthNotAvailableError)
    end

    it "AM-05: sets initial Realtime token in third-party mode" do
      callback = -> { "third-party-token" }
      described_class.new(url, key, access_token: callback)

      expect(realtime_client).to have_received(:set_auth).with("third-party-token")
    end
  end

  # ---- FW: Auth-wrapped Fetch Tests ----
  describe "auth-wrapped fetch" do
    it "FW-01: includes apikey header" do
      described_class.new(url, key)

      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(headers: hash_including("apikey" => key))
      )
    end

    it "FW-02: includes Authorization Bearer header with api key" do
      described_class.new(url, key)

      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(headers: hash_including("Authorization" => "Bearer #{key}"))
      )
    end

    it "FW-03: includes X-Client-Info header" do
      described_class.new(url, key)

      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(headers: hash_including("X-Client-Info" => "supabase-rb/#{Supabase::VERSION}"))
      )
    end

    it "FW-04: merges global user headers" do
      described_class.new(url, key, global: { headers: { "X-Custom" => "value" } })

      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(headers: hash_including("X-Custom" => "value"))
      )
    end

    it "FW-05: user headers override defaults" do
      custom_auth = "Bearer custom-token"
      described_class.new(url, key, global: { headers: { "Authorization" => custom_auth } })

      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(headers: hash_including("Authorization" => custom_auth))
      )
    end

    it "FW-06: functions accessor creates new client with current headers" do
      allow(Supabase::Functions::Client).to receive(:new).and_return(
        instance_double(Supabase::Functions::Client)
      )
      client = described_class.new(url, key)

      client.functions

      expect(Supabase::Functions::Client).to have_received(:new).with(
        hash_including(
          url: "#{url}/functions/v1",
          headers: hash_including("apikey" => key, "X-Client-Info" => "supabase-rb/#{Supabase::VERSION}")
        )
      )
    end
  end

  # ---- TP: Token Propagation to Realtime Tests ----
  describe "token propagation to Realtime" do
    it "TP-01: propagates token on signed_in event" do
      event_handler = nil
      allow(auth_client).to receive(:on_auth_state_change) do |&block|
        event_handler = block
        subscription
      end

      described_class.new(url, key)

      session = Supabase::Auth::Session.new("access_token" => "new-token", "refresh_token" => "rt")
      event_handler.call(:signed_in, session)

      expect(realtime_client).to have_received(:set_auth).with("new-token")
    end

    it "TP-02: propagates token on token_refreshed event" do
      event_handler = nil
      allow(auth_client).to receive(:on_auth_state_change) do |&block|
        event_handler = block
        subscription
      end

      described_class.new(url, key)

      session = Supabase::Auth::Session.new("access_token" => "refreshed-token", "refresh_token" => "rt")
      event_handler.call(:token_refreshed, session)

      expect(realtime_client).to have_received(:set_auth).with("refreshed-token")
    end

    it "TP-03: resets Realtime token on signed_out event" do
      event_handler = nil
      allow(auth_client).to receive(:on_auth_state_change) do |&block|
        event_handler = block
        subscription
      end

      described_class.new(url, key)
      event_handler.call(:signed_out, nil)

      expect(realtime_client).to have_received(:set_auth).with(nil)
    end

    it "TP-04: deduplicates token propagation" do
      event_handler = nil
      allow(auth_client).to receive(:on_auth_state_change) do |&block|
        event_handler = block
        subscription
      end

      described_class.new(url, key)

      session = Supabase::Auth::Session.new("access_token" => "same-token", "refresh_token" => "rt")
      event_handler.call(:signed_in, session)
      event_handler.call(:token_refreshed, session)

      # set_auth should only be called once with "same-token" (deduplicated)
      expect(realtime_client).to have_received(:set_auth).with("same-token").once
    end

    it "TP-05: does not propagate on irrelevant events" do
      event_handler = nil
      allow(auth_client).to receive(:on_auth_state_change) do |&block|
        event_handler = block
        subscription
      end

      described_class.new(url, key)
      event_handler.call(:user_updated, nil)

      # set_auth should not have been called (no propagation for user_updated)
      expect(realtime_client).not_to have_received(:set_auth)
    end

    it "TP-06: propagates new token after signed_out reset" do
      event_handler = nil
      allow(auth_client).to receive(:on_auth_state_change) do |&block|
        event_handler = block
        subscription
      end

      described_class.new(url, key)

      # First set a token
      session = Supabase::Auth::Session.new("access_token" => "first-token", "refresh_token" => "rt")
      event_handler.call(:signed_in, session)

      # Then sign out (resets token)
      event_handler.call(:signed_out, nil)

      # Then sign in again with new token
      new_session = Supabase::Auth::Session.new("access_token" => "second-token", "refresh_token" => "rt")
      event_handler.call(:signed_in, new_session)

      expect(realtime_client).to have_received(:set_auth).with("first-token").once
      expect(realtime_client).to have_received(:set_auth).with(nil).once
      expect(realtime_client).to have_received(:set_auth).with("second-token").once
    end
  end

  # ---- SD: Sub-client Delegation Tests ----
  describe "sub-client delegation" do
    let(:client) { described_class.new(url, key) }

    it "SD-01: delegates from() to PostgREST client" do
      query_builder = double("QueryBuilder")
      allow(postgrest_client).to receive(:from).with("users").and_return(query_builder)

      result = client.from("users")

      expect(result).to eq(query_builder)
      expect(postgrest_client).to have_received(:from).with("users")
    end

    it "SD-02: delegates schema() to PostgREST client" do
      schema_client = double("SchemaClient")
      allow(postgrest_client).to receive(:schema).with("public").and_return(schema_client)

      result = client.schema("public")

      expect(result).to eq(schema_client)
    end

    it "SD-03: delegates rpc() to PostgREST client" do
      rpc_response = double("Response", data: [1, 2, 3])
      allow(postgrest_client).to receive(:rpc).with("my_function", args: { x: 1 }).and_return(rpc_response)

      result = client.rpc("my_function", args: { x: 1 })

      expect(result).to eq(rpc_response)
    end

    it "SD-04: delegates channel() to Realtime client" do
      channel = double("Channel")
      allow(realtime_client).to receive(:channel).with("room1", config: {}).and_return(channel)

      result = client.channel("room1")

      expect(result).to eq(channel)
    end

    it "SD-05: delegates get_channels to Realtime client" do
      channels = [double("Channel1"), double("Channel2")]
      allow(realtime_client).to receive(:get_channels).and_return(channels)

      result = client.get_channels

      expect(result).to eq(channels)
    end

    it "SD-06: delegates remove_channel to Realtime client" do
      channel = double("Channel")
      allow(realtime_client).to receive(:remove_channel).with(channel)

      client.remove_channel(channel)

      expect(realtime_client).to have_received(:remove_channel).with(channel)
    end

    it "SD-07: delegates remove_all_channels to Realtime client" do
      allow(realtime_client).to receive(:remove_all_channels)

      client.remove_all_channels

      expect(realtime_client).to have_received(:remove_all_channels)
    end

    it "SD-08: auth accessor returns Auth client in session mode" do
      expect(client.auth).to eq(auth_client)
    end

    it "SD-09: storage accessor returns Storage client" do
      expect(client.storage).to eq(storage_client)
    end

    it "SD-10: functions accessor creates new Functions client each time" do
      func1 = instance_double(Supabase::Functions::Client)
      func2 = instance_double(Supabase::Functions::Client)
      allow(Supabase::Functions::Client).to receive(:new).and_return(func1, func2)

      result1 = client.functions
      result2 = client.functions

      expect(result1).to eq(func1)
      expect(result2).to eq(func2)
      expect(Supabase::Functions::Client).to have_received(:new).twice
    end
  end

  # ---- CD: Configuration Defaults Tests ----
  describe "configuration defaults" do
    it "CD-01: passes apikey param to Realtime client" do
      described_class.new(url, key)

      expect(Supabase::Realtime::Client).to have_received(:new).with(
        anything,
        hash_including(params: hash_including(apikey: key))
      )
    end

    it "CD-02: passes custom db schema to PostgREST client" do
      described_class.new(url, key, db: { schema: "custom_schema" })

      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(schema: "custom_schema")
      )
    end

    it "CD-03: passes default auth options to Auth client" do
      described_class.new(url, key)

      expect(Supabase::Auth::Client).to have_received(:new).with(
        hash_including(
          auto_refresh_token: true,
          persist_session: true,
          flow_type: :implicit
        )
      )
    end

    it "CD-04: merges user auth options with defaults" do
      described_class.new(url, key, auth: { flow_type: :pkce, persist_session: false })

      expect(Supabase::Auth::Client).to have_received(:new).with(
        hash_including(
          flow_type: :pkce,
          persist_session: false,
          auto_refresh_token: true
        )
      )
    end

    it "CD-05: merges custom realtime params" do
      described_class.new(url, key, realtime: { params: { log_level: "info" } })

      expect(Supabase::Realtime::Client).to have_received(:new).with(
        anything,
        hash_including(params: hash_including(apikey: key, log_level: "info"))
      )
    end

    it "CD-06: passes custom fetch to PostgREST client" do
      custom_fetch = proc { |_req| "response" }
      described_class.new(url, key, global: { fetch: custom_fetch })

      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(fetch: custom_fetch)
      )
    end

    it "CD-07: passes custom fetch to Storage client" do
      custom_fetch = proc { |_req| "response" }
      described_class.new(url, key, global: { fetch: custom_fetch })

      expect(Supabase::Storage::Client).to have_received(:new).with(
        hash_including(fetch: custom_fetch)
      )
    end

    it "CD-08: strips trailing slash from base URL" do
      described_class.new("#{url}/", key)

      expect(Supabase::Auth::Client).to have_received(:new).with(
        hash_including(url: "#{url}/auth/v1")
      )
    end
  end

  # ---- X-Client-Info / Environment Detection Tests ----
  describe "X-Client-Info header" do
    it "sends supabase-rb/{VERSION} to all sub-clients" do
      expected_info = "supabase-rb/#{Supabase::VERSION}"

      described_class.new(url, key)

      expect(Supabase::Auth::Client).to have_received(:new).with(
        hash_including(headers: hash_including("X-Client-Info" => expected_info))
      )
      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(headers: hash_including("X-Client-Info" => expected_info))
      )
      expect(Supabase::Storage::Client).to have_received(:new).with(
        hash_including(headers: hash_including("X-Client-Info" => expected_info))
      )
    end
  end

  # ---- Error Hierarchy Tests ----
  describe "error hierarchy" do
    it "SupabaseError is a StandardError" do
      expect(Supabase::SupabaseError.new).to be_a(StandardError)
    end

    it "SupabaseError has context attribute" do
      error = Supabase::SupabaseError.new("msg", context: { foo: "bar" })
      expect(error.context).to eq({ foo: "bar" })
      expect(error.message).to eq("msg")
    end

    it "AuthNotAvailableError inherits from SupabaseError" do
      expect(Supabase::AuthNotAvailableError.new).to be_a(Supabase::SupabaseError)
    end
  end

  # ---- Supabase.create_client Factory ----
  describe "Supabase.create_client" do
    it "creates a Client via module-level factory method" do
      client = Supabase.create_client(url, key)

      expect(client).to be_a(Supabase::Client)
    end

    it "passes options through to Client.new" do
      custom_fetch = proc { |_req| "response" }
      client = Supabase.create_client(url, key, global: { fetch: custom_fetch })

      expect(client).to be_a(Supabase::Client)
      expect(Supabase::PostgREST::Client).to have_received(:new).with(
        hash_including(fetch: custom_fetch)
      )
    end
  end

  # ---- Token Resolution Tests ----
  describe "token resolution for functions" do
    it "uses access_token callback for functions headers in third-party mode" do
      call_count = 0
      callback = lambda do
        call_count += 1
        "dynamic-token-#{call_count}"
      end

      allow(Supabase::Functions::Client).to receive(:new).and_return(
        instance_double(Supabase::Functions::Client)
      )

      client = described_class.new(url, key, access_token: callback)
      client.functions

      expect(Supabase::Functions::Client).to have_received(:new).with(
        hash_including(headers: hash_including("Authorization" => "Bearer dynamic-token-2"))
      )
    end

    it "uses session token for functions headers in session mode" do
      session = Supabase::Auth::Session.new("access_token" => "session-token", "refresh_token" => "rt")
      allow(auth_client).to receive(:get_session).and_return(
        { session: session }
      )
      allow(Supabase::Functions::Client).to receive(:new).and_return(
        instance_double(Supabase::Functions::Client)
      )

      client = described_class.new(url, key)
      client.functions

      expect(Supabase::Functions::Client).to have_received(:new).with(
        hash_including(headers: hash_including("Authorization" => "Bearer session-token"))
      )
    end

    it "falls back to api key when session retrieval fails" do
      allow(auth_client).to receive(:get_session).and_raise(StandardError, "something failed")
      allow(Supabase::Functions::Client).to receive(:new).and_return(
        instance_double(Supabase::Functions::Client)
      )

      client = described_class.new(url, key)
      client.functions

      expect(Supabase::Functions::Client).to have_received(:new).with(
        hash_including(headers: hash_including("Authorization" => "Bearer #{key}"))
      )
    end
  end

  # ---- Realtime Params Configuration ----
  describe "realtime configuration" do
    it "passes extra realtime options besides params" do
      described_class.new(
        url, key, realtime: {
          params: { log_level: "info" },
          timeout: 30_000,
          heartbeat_interval_ms: 15_000
        }
      )

      expect(Supabase::Realtime::Client).to have_received(:new).with(
        anything,
        hash_including(
          timeout: 30_000,
          heartbeat_interval_ms: 15_000,
          params: hash_including(apikey: key, log_level: "info")
        )
      )
    end
  end

  # ---- URL Port Handling Tests ----
  describe "URL port handling" do
    it "includes non-standard port in Realtime URL" do
      described_class.new("http://localhost:54321", key)

      expect(Supabase::Realtime::Client).to have_received(:new).with(
        "ws://localhost:54321/realtime/v1",
        anything
      )
    end

    it "omits standard HTTPS port (443) from Realtime URL" do
      described_class.new("https://myproject.supabase.co:443", key)

      expect(Supabase::Realtime::Client).to have_received(:new).with(
        "wss://myproject.supabase.co/realtime/v1",
        anything
      )
    end

    it "omits standard HTTP port (80) from Realtime URL" do
      described_class.new("http://myproject.supabase.co:80", key)

      expect(Supabase::Realtime::Client).to have_received(:new).with(
        "ws://myproject.supabase.co/realtime/v1",
        anything
      )
    end
  end
end
