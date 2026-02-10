# frozen_string_literal: true

RSpec.describe Supabase::Functions::Client do
  let(:base_url) { "https://example.supabase.co/functions/v1" }
  let(:default_headers) { { "apikey" => "test-api-key" } }
  let(:client) { described_class.new(url: base_url, headers: default_headers) }

  # ---------------------------------------------------------------------------
  # AU: Authentication / set_auth
  # ---------------------------------------------------------------------------
  describe "#set_auth" do
    it "AU-01: sets the Authorization bearer token for subsequent requests" do
      stub = stub_request(:post, "#{base_url}/hello")
             .with(headers: { "Authorization" => "Bearer my-token" })
             .to_return(status: 200, body: '{"ok":true}', headers: { "content-type" => "application/json" })

      client.set_auth("my-token")
      result = client.invoke("hello")

      expect(stub).to have_been_requested
      expect(result).to eq("ok" => true)
    end

    it "AU-02: token persists across multiple invocations" do
      client.set_auth("persistent-token")

      stub1 = stub_request(:post, "#{base_url}/fn1")
              .with(headers: { "Authorization" => "Bearer persistent-token" })
              .to_return(status: 200, body: "ok", headers: { "content-type" => "text/plain" })
      stub2 = stub_request(:post, "#{base_url}/fn2")
              .with(headers: { "Authorization" => "Bearer persistent-token" })
              .to_return(status: 200, body: "ok", headers: { "content-type" => "text/plain" })

      client.invoke("fn1")
      client.invoke("fn2")

      expect(stub1).to have_been_requested
      expect(stub2).to have_been_requested
    end

    it "AU-03: overrides previously set token" do
      client.set_auth("old-token")
      client.set_auth("new-token")

      stub = stub_request(:post, "#{base_url}/hello")
             .with(headers: { "Authorization" => "Bearer new-token" })
             .to_return(status: 200, body: "", headers: {})

      client.invoke("hello")
      expect(stub).to have_been_requested
    end

    it "AU-04: does not send Authorization header when no token is set" do
      stub_request(:post, "#{base_url}/hello")
        .to_return(status: 200, body: "", headers: {})

      client.invoke("hello")

      expect(
        a_request(:post, "#{base_url}/hello")
          .with { |req| !req.headers.key?("Authorization") }
      ).to have_been_made
    end

    it "AU-05: set_auth can be called without error" do
      client.set_auth("token")
    end
  end

  # ---------------------------------------------------------------------------
  # BH: Body Handling (auto-detection and serialization)
  # ---------------------------------------------------------------------------
  describe "body auto-detection" do
    it "BH-01: String body sets Content-Type to text/plain" do
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "Content-Type" => "text/plain" }, body: "hello world")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", body: "hello world")
      expect(stub).to have_been_requested
    end

    it "BH-02: Hash body sets Content-Type to application/json and serializes to JSON" do
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "Content-Type" => "application/json" }, body: '{"key":"value"}')
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", body: { key: "value" })
      expect(stub).to have_been_requested
    end

    it "BH-03: Array body sets Content-Type to application/json and serializes to JSON" do
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "Content-Type" => "application/json" }, body: "[1,2,3]")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", body: [1, 2, 3])
      expect(stub).to have_been_requested
    end

    it "BH-04: IO body sets Content-Type to application/octet-stream" do
      io = StringIO.new("binary data")
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "Content-Type" => "application/octet-stream" }, body: "binary data")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", body: io)
      expect(stub).to have_been_requested
    end

    it "BH-05: nil body sends no body" do
      stub = stub_request(:post, "#{base_url}/fn")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", body: nil)
      expect(stub).to have_been_requested
    end

    it "BH-06: StringIO body sets Content-Type to application/octet-stream and reads content" do
      sio = StringIO.new("\x00\x01\x02")
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "Content-Type" => "application/octet-stream" }, body: "\x00\x01\x02")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", body: sio)
      expect(stub).to have_been_requested
    end

    it "BH-07: nested Hash body is correctly JSON-serialized" do
      payload = { user: { name: "Alice", tags: %w[admin active] } }
      stub = stub_request(:post, "#{base_url}/fn")
             .with(body: JSON.generate(payload))
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", body: payload)
      expect(stub).to have_been_requested
    end

    it "BH-08: empty string body sends text/plain with empty body" do
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "Content-Type" => "text/plain" }, body: "")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", body: "")
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # RP: Response Parsing
  # ---------------------------------------------------------------------------
  describe "response parsing" do
    it "RP-01: JSON content-type is parsed into a Hash" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: '{"result":"ok"}', headers: { "content-type" => "application/json" })

      result = client.invoke("fn")
      expect(result).to eq("result" => "ok")
    end

    it "RP-02: JSON array content-type is parsed into an Array" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "[1,2,3]", headers: { "content-type" => "application/json" })

      result = client.invoke("fn")
      expect(result).to eq([1, 2, 3])
    end

    it "RP-03: text/plain is returned as a string" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "plain text response", headers: { "content-type" => "text/plain" })

      result = client.invoke("fn")
      expect(result).to eq("plain text response")
    end

    it "RP-04: application/octet-stream returns binary string" do
      binary_data = "\x00\x01\xFF"
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: binary_data, headers: { "content-type" => "application/octet-stream" })

      result = client.invoke("fn")
      expect(result).to eq(binary_data.b)
      expect(result.encoding).to eq(Encoding::ASCII_8BIT)
    end

    it "RP-05: text/event-stream returns the raw response object" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "data: hello\n\n", headers: { "content-type" => "text/event-stream" })

      result = client.invoke("fn")
      expect(result).to respond_to(:status)
      expect(result).to respond_to(:headers)
      expect(result).to respond_to(:body)
    end

    it "RP-06: JSON with charset is still parsed" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: '{"ok":true}', headers: { "content-type" => "application/json; charset=utf-8" })

      result = client.invoke("fn")
      expect(result).to eq("ok" => true)
    end

    it "RP-07: unknown content-type returns body as string" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "<html>page</html>", headers: { "content-type" => "text/html" })

      result = client.invoke("fn")
      expect(result).to eq("<html>page</html>")
    end

    it "RP-08: missing content-type returns body as string" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "raw", headers: {})

      result = client.invoke("fn")
      expect(result).to eq("raw")
    end
  end

  # ---------------------------------------------------------------------------
  # EH: Error Handling
  # ---------------------------------------------------------------------------
  describe "error handling" do
    it "EH-01: non-2xx response raises FunctionsHttpError" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 500, body: "Internal Server Error", headers: {})

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsHttpError, "Internal Server Error") { |e|
          expect(e.status).to eq(500)
        }
    end

    it "EH-02: 404 response raises FunctionsHttpError with status 404" do
      stub_request(:post, "#{base_url}/missing")
        .to_return(status: 404, body: "Not Found", headers: {})

      expect { client.invoke("missing") }
        .to raise_error(Supabase::Functions::FunctionsHttpError) { |e|
          expect(e.status).to eq(404)
        }
    end

    it "EH-03: relay error (x-relay-error header) raises FunctionsRelayError" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 500, body: "relay failure", headers: { "x-relay-error" => "true" })

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsRelayError, "relay failure") { |e|
          expect(e.status).to eq(500)
        }
    end

    it "EH-04: relay error takes precedence over HTTP error for non-2xx with relay header" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 502, body: "bad gateway relay", headers: { "x-relay-error" => "true" })

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsRelayError)
    end

    it "EH-05: network error raises FunctionsFetchError" do
      stub_request(:post, "#{base_url}/fn")
        .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsFetchError, /Connection refused/)
    end

    it "EH-06: timeout error raises FunctionsFetchError" do
      stub_request(:post, "#{base_url}/fn")
        .to_raise(Faraday::TimeoutError.new("execution expired"))

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsFetchError, /execution expired/)
    end

    it "EH-07: FunctionsHttpError has context pointing to the response" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 403, body: "Forbidden", headers: {})

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsHttpError) { |e|
          expect(e.context).to respond_to(:status)
          expect(e.context.status).to eq(403)
        }
    end

    it "EH-08: FunctionsFetchError has context pointing to the original exception" do
      stub_request(:post, "#{base_url}/fn")
        .to_raise(Faraday::ConnectionFailed.new("oops"))

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsFetchError) { |e|
          expect(e.context).to be_a(Faraday::ConnectionFailed)
        }
    end
  end

  # ---------------------------------------------------------------------------
  # RR: Region Routing
  # ---------------------------------------------------------------------------
  describe "region routing" do
    it "RR-01: default region :any does not set x-region header or query param" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "", headers: {})

      client.invoke("fn")

      expect(
        a_request(:post, "#{base_url}/fn")
          .with { |req| !req.headers.key?("X-Region") && req.uri.query.nil? }
      ).to have_been_made
    end

    it "RR-02: client-level region sets x-region header and forceFunctionRegion query param" do
      regional_client = described_class.new(url: base_url, headers: default_headers, region: "us-east-1")
      stub = stub_request(:post, "#{base_url}/fn?forceFunctionRegion=us-east-1")
             .with(headers: { "x-region" => "us-east-1" })
             .to_return(status: 200, body: "", headers: {})

      regional_client.invoke("fn")
      expect(stub).to have_been_requested
    end

    it "RR-03: invoke-level region overrides client-level region" do
      regional_client = described_class.new(url: base_url, headers: default_headers, region: "us-east-1")
      stub = stub_request(:post, "#{base_url}/fn?forceFunctionRegion=eu-west-1")
             .with(headers: { "x-region" => "eu-west-1" })
             .to_return(status: 200, body: "", headers: {})

      regional_client.invoke("fn", region: "eu-west-1")
      expect(stub).to have_been_requested
    end

    it "RR-04: invoke region :any overrides client region (no region routing)" do
      regional_client = described_class.new(url: base_url, headers: default_headers, region: "us-east-1")
      stub = stub_request(:post, "#{base_url}/fn")
             .to_return(status: 200, body: "", headers: {})

      regional_client.invoke("fn", region: :any)
      expect(stub).to have_been_requested
    end

    it "RR-05: region symbol is converted to string in header and query param" do
      regional_client = described_class.new(url: base_url, headers: default_headers, region: :ap_southeast1)
      stub = stub_request(:post, "#{base_url}/fn?forceFunctionRegion=ap_southeast1")
             .with(headers: { "x-region" => "ap_southeast1" })
             .to_return(status: 200, body: "", headers: {})

      regional_client.invoke("fn")
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # TC: Timeout Configuration
  # ---------------------------------------------------------------------------
  describe "timeout behavior" do
    it "TC-01: default client has no timeout (Faraday defaults)" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "", headers: {})

      expect { client.invoke("fn") }.not_to raise_error
    end

    it "TC-02: per-request timeout is passed to the connection" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "", headers: {})

      expect { client.invoke("fn", timeout: 5) }.not_to raise_error
    end

    it "TC-03: timeout expiry raises FunctionsFetchError" do
      stub_request(:post, "#{base_url}/fn")
        .to_raise(Faraday::TimeoutError.new("execution expired"))

      expect { client.invoke("fn", timeout: 1) }
        .to raise_error(Supabase::Functions::FunctionsFetchError)
    end

    it "TC-04: custom fetch proc receives timeout" do
      received_timeout = nil
      custom_fetch = lambda { |timeout|
        received_timeout = timeout
        Faraday.new do |f|
          f.adapter :test do |s|
            s.post("/fn") { [200, {}, ""] }
          end
        end
      }

      custom_client = described_class.new(url: "", headers: {}, fetch: custom_fetch)
      custom_client.invoke("fn", timeout: 42)

      expect(received_timeout).to eq(42)
    end

    it "TC-05: custom fetch proc receives nil timeout when not specified" do
      received_timeout = :not_set
      custom_fetch = lambda { |timeout|
        received_timeout = timeout
        Faraday.new do |f|
          f.adapter :test do |s|
            s.post("/fn") { [200, {}, ""] }
          end
        end
      }

      custom_client = described_class.new(url: "", headers: {}, fetch: custom_fetch)
      custom_client.invoke("fn")

      expect(received_timeout).to be_nil
    end
  end

  # ---------------------------------------------------------------------------
  # HP: Header Precedence
  # ---------------------------------------------------------------------------
  describe "header precedence" do
    it "HP-01: invoke-level headers override client-level headers" do
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "X-Custom" => "invoke-value" })
             .to_return(status: 200, body: "", headers: {})

      custom_client = described_class.new(url: base_url, headers: { "X-Custom" => "client-value" })
      custom_client.invoke("fn", headers: { "X-Custom" => "invoke-value" })

      expect(stub).to have_been_requested
    end

    it "HP-02: client-level headers override auto-detected headers" do
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "Content-Type" => "application/xml" })
             .to_return(status: 200, body: "", headers: {})

      custom_client = described_class.new(url: base_url, headers: { "Content-Type" => "application/xml" })
      custom_client.invoke("fn", body: { key: "value" })

      expect(stub).to have_been_requested
    end

    it "HP-03: invoke-level headers override both client and auto-detected" do
      stub = stub_request(:post, "#{base_url}/fn")
             .with(headers: { "Content-Type" => "text/csv" })
             .to_return(status: 200, body: "", headers: {})

      custom_client = described_class.new(url: base_url, headers: { "Content-Type" => "application/xml" })
      custom_client.invoke("fn", body: { key: "value" }, headers: { "Content-Type" => "text/csv" })

      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # HM: HTTP Methods
  # ---------------------------------------------------------------------------
  describe "HTTP methods" do
    it "HM-01: defaults to POST" do
      stub = stub_request(:post, "#{base_url}/fn")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn")
      expect(stub).to have_been_requested
    end

    it "HM-02: supports GET method" do
      stub = stub_request(:get, "#{base_url}/fn")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", method: :get)
      expect(stub).to have_been_requested
    end

    it "HM-03: supports PUT method" do
      stub = stub_request(:put, "#{base_url}/fn")
             .to_return(status: 200, body: '{"updated":true}', headers: { "content-type" => "application/json" })

      result = client.invoke("fn", method: :put, body: { name: "test" })
      expect(stub).to have_been_requested
      expect(result).to eq("updated" => true)
    end

    it "HM-04: supports PATCH method" do
      stub = stub_request(:patch, "#{base_url}/fn")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", method: :patch)
      expect(stub).to have_been_requested
    end

    it "HM-05: supports DELETE method" do
      stub = stub_request(:delete, "#{base_url}/fn")
             .to_return(status: 200, body: "", headers: {})

      client.invoke("fn", method: :delete)
      expect(stub).to have_been_requested
    end
  end

  # ---------------------------------------------------------------------------
  # Error hierarchy
  # ---------------------------------------------------------------------------
  describe "error hierarchy" do
    it "FunctionsError is a Module (mixin)" do
      expect(Supabase::Functions::FunctionsError).to be_a(Module)
    end

    it "FunctionsBaseError inherits from Supabase::Error and includes FunctionsError" do
      expect(Supabase::Functions::FunctionsBaseError.superclass).to eq(Supabase::Error)
      err = Supabase::Functions::FunctionsBaseError.new("msg")
      expect(err).to be_a(Supabase::Functions::FunctionsError)
    end

    it "FunctionsFetchError inherits from Supabase::NetworkError and includes FunctionsError" do
      expect(Supabase::Functions::FunctionsFetchError.superclass).to eq(Supabase::NetworkError)
      err = Supabase::Functions::FunctionsFetchError.new("msg")
      expect(err).to be_a(Supabase::Functions::FunctionsError)
    end

    it "FunctionsRelayError inherits from Supabase::ApiError and includes FunctionsError" do
      expect(Supabase::Functions::FunctionsRelayError.superclass).to eq(Supabase::ApiError)
      err = Supabase::Functions::FunctionsRelayError.new("msg")
      expect(err).to be_a(Supabase::Functions::FunctionsError)
    end

    it "FunctionsHttpError inherits from Supabase::ApiError and includes FunctionsError" do
      expect(Supabase::Functions::FunctionsHttpError.superclass).to eq(Supabase::ApiError)
      err = Supabase::Functions::FunctionsHttpError.new("msg")
      expect(err).to be_a(Supabase::Functions::FunctionsError)
    end

    it "FunctionsBaseError stores context" do
      err = Supabase::Functions::FunctionsBaseError.new("msg", context: :ctx)
      expect(err.context).to eq(:ctx)
      expect(err.message).to eq("msg")
    end

    it "FunctionsRelayError stores status" do
      err = Supabase::Functions::FunctionsRelayError.new("msg", status: 502)
      expect(err.status).to eq(502)
    end

    it "FunctionsHttpError stores status" do
      err = Supabase::Functions::FunctionsHttpError.new("msg", status: 403)
      expect(err.status).to eq(403)
    end
  end

  # ---------------------------------------------------------------------------
  # Constructor
  # ---------------------------------------------------------------------------
  describe "#initialize" do
    it "strips trailing slash from URL" do
      c = described_class.new(url: "https://example.com/functions/v1/", headers: {})
      stub = stub_request(:post, "https://example.com/functions/v1/hello")
             .to_return(status: 200, body: "", headers: {})

      c.invoke("hello")
      expect(stub).to have_been_requested
    end

    it "accepts custom fetch proc" do
      called = false
      custom_fetch = lambda { |_timeout|
        called = true
        Faraday.new do |f|
          f.adapter :test do |s|
            s.post("/fn") { [200, {}, ""] }
          end
        end
      }

      c = described_class.new(url: "", headers: {}, fetch: custom_fetch)
      c.invoke("fn")
      expect(called).to be true
    end

    it "defaults region to :any" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "", headers: {})

      client.invoke("fn")
      expect(
        a_request(:post, "#{base_url}/fn")
          .with { |req| req.uri.query.nil? }
      ).to have_been_made
    end
  end

  # ---------------------------------------------------------------------------
  # Invalid method
  # ---------------------------------------------------------------------------
  describe "invalid HTTP method" do
    it "raises FunctionsFetchError for unsupported method" do
      expect { client.invoke("fn", method: :options) }
        .to raise_error(Supabase::Functions::FunctionsFetchError, /Invalid HTTP method/)
    end
  end

  # ---------------------------------------------------------------------------
  # Integration-style tests
  # ---------------------------------------------------------------------------
  describe "integration scenarios" do
    it "full flow: set_auth, invoke with JSON body, get parsed response" do
      client.set_auth("jwt-token")

      stub = stub_request(:post, "#{base_url}/process-data")
             .with(
               headers: {
                 "Authorization" => "Bearer jwt-token",
                 "apikey" => "test-api-key",
                 "Content-Type" => "application/json"
               },
               body: '{"input":"data"}'
             )
             .to_return(
               status: 200,
               body: '{"output":"result"}',
               headers: { "content-type" => "application/json" }
             )

      result = client.invoke("process-data", body: { input: "data" })

      expect(stub).to have_been_requested
      expect(result).to eq("output" => "result")
    end

    it "regional invocation with custom headers" do
      regional_client = described_class.new(
        url: base_url, headers: { "apikey" => "key" }, region: "eu-central-1"
      )

      stub = stub_request(:post, "#{base_url}/compute?forceFunctionRegion=eu-central-1")
             .with(headers: { "x-region" => "eu-central-1", "apikey" => "key", "X-Request-Id" => "abc-123" })
             .to_return(status: 200, body: '{"done":true}', headers: { "content-type" => "application/json" })

      result = regional_client.invoke("compute", body: { task: "run" },
                                                 headers: { "X-Request-Id" => "abc-123" })

      expect(stub).to have_been_requested
      expect(result).to eq("done" => true)
    end

    it "GET request with no body" do
      stub = stub_request(:get, "#{base_url}/health")
             .to_return(status: 200, body: '{"status":"healthy"}',
                        headers: { "content-type" => "application/json" })

      result = client.invoke("health", method: :get)

      expect(stub).to have_been_requested
      expect(result).to eq("status" => "healthy")
    end

    it "relay error on 2xx status still raises FunctionsRelayError" do
      stub_request(:post, "#{base_url}/fn")
        .to_return(status: 200, body: "edge function boot error", headers: { "x-relay-error" => "true" })

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsRelayError) { |e|
          expect(e.status).to eq(200)
        }
    end

    it "IOError during request raises FunctionsFetchError" do
      stub_request(:post, "#{base_url}/fn")
        .to_raise(IOError.new("stream closed"))

      expect { client.invoke("fn") }
        .to raise_error(Supabase::Functions::FunctionsFetchError, /stream closed/)
    end
  end
end
