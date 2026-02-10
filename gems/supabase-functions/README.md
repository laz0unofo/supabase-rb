# Supabase Functions (Ruby)

Ruby client for [Supabase Edge Functions](https://supabase.com/docs/guides/functions). Invoke serverless functions with automatic body serialization, response parsing, and region routing.

## Installation

```ruby
gem "supabase-functions"
```

## Usage

```ruby
require "supabase/functions"

client = Supabase::Functions::Client.new(
  url: "https://your-project.supabase.co/functions/v1",
  headers: { "apikey" => "your-key", "Authorization" => "Bearer your-key" }
)

result = client.invoke("hello-world", body: { name: "Ruby" })
puts result[:data]  # => { "message" => "Hello, Ruby!" }
```

## API Reference

### `Supabase::Functions::Client`

#### `initialize(url:, headers: {}, region: :any, fetch: nil)`

Creates a new Functions client.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `url` | String | _(required)_ | Base URL of the Functions service |
| `headers` | Hash | `{}` | Default headers for all requests |
| `region` | Symbol | `:any` | Default region for function execution |
| `fetch` | Proc | `nil` | Custom Faraday connection factory |

#### `set_auth(token)`

Sets the Bearer token for all subsequent requests.

```ruby
client.set_auth("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...")
```

#### `invoke(function_name, **options) -> Hash`

Invokes a Supabase Edge Function.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `body` | Object | `nil` | Request body (auto-serialized) |
| `headers` | Hash | `{}` | Per-request headers |
| `method` | Symbol | `:post` | HTTP method (`:get`, `:post`, `:put`, `:patch`, `:delete`) |
| `region` | Symbol | `nil` | Region override |
| `timeout` | Integer | `nil` | Request timeout in seconds |

**Body auto-detection:**

| Body Type | Content-Type |
|-----------|-------------|
| `String` | `text/plain` |
| `Hash` / `Array` | `application/json` (auto-serialized) |
| `IO` / `StringIO` | `application/octet-stream` |
| `nil` | _(no body sent)_ |

**Response parsing:**

| Response Content-Type | Parsed As |
|----------------------|-----------|
| `application/json` | Parsed JSON (Hash/Array) |
| `application/octet-stream` | Binary string |
| `text/event-stream` | Raw Faraday response |
| `text/*` | String |

**Returns:** `{ data: <response>, error: nil }` or `{ data: nil, error: <FunctionsError> }`

```ruby
# JSON body
client.invoke("process", body: { items: [1, 2, 3] })

# GET request
client.invoke("status", method: :get)

# With timeout
client.invoke("slow-function", body: {}, timeout: 30)

# Region routing
client.invoke("compute", body: {}, region: :us_east_1)
```

### Header Precedence

Headers are merged in this order (later overrides earlier):

1. Auto-detected Content-Type
2. Client-level headers (from constructor)
3. Per-invoke headers

## Error Hierarchy

| Error Class | When |
|------------|------|
| `FunctionsError` | Base class |
| `FunctionsFetchError` | Network failures, timeouts |
| `FunctionsRelayError` | Relay/gateway errors (`x-relay-error` header) |
| `FunctionsHttpError` | Non-2xx HTTP responses |

```ruby
result = client.invoke("my-function")
if result[:error]
  case result[:error]
  when Supabase::Functions::FunctionsHttpError
    puts "HTTP error: #{result[:error].message}"
  when Supabase::Functions::FunctionsFetchError
    puts "Network error: #{result[:error].message}"
  end
end
```
