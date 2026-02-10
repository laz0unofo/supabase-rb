# Supabase Ruby SDK

A complete, idiomatic Ruby SDK for [Supabase](https://supabase.com). Provides access to Auth, PostgREST, Realtime, Storage, and Edge Functions through a single client or as independent gems.

## Installation

### Full SDK (recommended)

Add the top-level gem to your Gemfile:

```ruby
gem "supabase"
```

This installs all service modules and provides a unified `Supabase::Client`.

### Individual Gems

Use only the services you need:

```ruby
gem "supabase-auth"       # Authentication (GoTrue)
gem "supabase-postgrest"  # Database queries (PostgREST)
gem "supabase-realtime"   # Real-time subscriptions (WebSocket)
gem "supabase-storage"    # File storage
gem "supabase-functions"  # Edge Functions
```

## Quick Start

### Combined Usage

```ruby
require "supabase"

client = Supabase.create_client(
  "https://your-project.supabase.co",
  "your-anon-key"
)

# Database queries
result = client.from("posts").select("*").eq("published", true).execute
puts result[:data]

# Auth
result = client.auth.sign_in_with_password(email: "user@example.com", password: "secret")
session = result[:data][:session]

# Storage
result = client.storage.from("avatars").upload("photo.png", File.open("photo.png"))

# Edge Functions
result = client.functions.invoke("hello", body: { name: "World" })

# Realtime
channel = client.channel("room1")
channel.on_broadcast("message") { |payload| puts payload }
channel.subscribe
```

### Independent Gem Usage

Each gem works standalone without the top-level orchestrator:

```ruby
require "supabase/postgrest"

db = Supabase::PostgREST::Client.new(
  url: "https://your-project.supabase.co/rest/v1",
  headers: { "apikey" => "your-key", "Authorization" => "Bearer your-key" }
)

result = db.from("users").select("id, name, email").eq("active", true).order("name").execute
puts result[:data]
```

## API Overview

All methods return `{ data:, error: }` hashes and never raise exceptions by default. Use `.throw_on_error` (PostgREST) to opt into exceptions.

### Database (PostgREST)

```ruby
# SELECT
client.from("posts")
  .select("id, title, author:users(name)")
  .eq("published", true)
  .order("created_at", ascending: false)
  .limit(10)
  .execute

# INSERT
client.from("posts")
  .insert({ title: "Hello", body: "World" })
  .execute

# UPDATE
client.from("posts")
  .update({ published: true })
  .eq("id", 1)
  .execute

# UPSERT
client.from("posts")
  .upsert({ id: 1, title: "Updated" }, on_conflict: "id")
  .execute

# DELETE
client.from("posts")
  .delete
  .eq("id", 1)
  .execute

# RPC (stored procedures)
client.rpc("get_total_posts", args: { status: "published" })
```

### Authentication

```ruby
# Sign up
client.auth.sign_up(email: "user@example.com", password: "secure-password")

# Sign in with password
client.auth.sign_in_with_password(email: "user@example.com", password: "secure-password")

# Sign in with OAuth (returns URL to redirect to)
result = client.auth.sign_in_with_oauth(provider: "github", redirect_to: "https://myapp.com/callback")
redirect_url = result[:data][:url]

# Sign in with OTP (magic link)
client.auth.sign_in_with_otp(email: "user@example.com")

# Get current session
session = client.auth.get_session[:data][:session]

# Get current user
user = client.auth.get_user[:data][:user]

# Sign out
client.auth.sign_out

# Listen for auth state changes
subscription = client.auth.on_auth_state_change do |event, session|
  puts "Auth event: #{event}"
end

# MFA
client.auth.mfa.enroll(factor_type: "totp", friendly_name: "My TOTP")
client.auth.mfa.challenge(factor_id: factor_id)
client.auth.mfa.verify(factor_id: factor_id, challenge_id: challenge_id, code: "123456")

# Admin (requires service role key)
client.auth.admin.list_users(page: 1, per_page: 50)
client.auth.admin.create_user(email: "new@example.com", password: "temp", email_confirm: true)
```

### Storage

```ruby
bucket = client.storage.from("avatars")

# Upload
bucket.upload("user1/photo.png", File.open("photo.png"), content_type: "image/png")

# Download
result = bucket.download("user1/photo.png")
File.write("downloaded.png", result[:data])

# Public URL
url = bucket.get_public_url("user1/photo.png")[:data][:public_url]

# Signed URL (expires in 1 hour)
url = bucket.create_signed_url("user1/photo.png", 3600)[:data][:signed_url]

# Image transforms
url = bucket.get_public_url("user1/photo.png", transform: { width: 200, height: 200 })

# List files
files = bucket.list("user1/")[:data]

# Move / Copy / Delete
bucket.move("old/path.png", "new/path.png")
bucket.copy("source.png", "copy.png")
bucket.remove(["user1/photo.png"])

# Bucket management
client.storage.list_buckets
client.storage.create_bucket("my-bucket", public: true)
client.storage.delete_bucket("my-bucket")
```

### Realtime

```ruby
# Subscribe to broadcast messages
channel = client.channel("room1")
channel.on_broadcast("cursor_move") do |payload|
  puts "User moved cursor to #{payload}"
end
channel.subscribe

# Send broadcast
channel.send_broadcast(event: "cursor_move", payload: { x: 100, y: 200 })

# Presence tracking
channel = client.channel("lobby")
channel.on_presence(:sync) { puts "Presence synced" }
channel.on_presence(:join) { |data| puts "User joined: #{data}" }
channel.on_presence(:leave) { |data| puts "User left: #{data}" }
channel.subscribe
channel.track({ user_id: "user1", online_at: Time.now.iso8601 })

# Listen to database changes (CDC)
channel = client.channel("db-changes")
channel.on_postgres_changes(
  event: :insert,
  schema: "public",
  table: "posts"
) do |payload|
  puts "New post: #{payload}"
end
channel.subscribe
```

### Edge Functions

```ruby
# Invoke a function
result = client.functions.invoke("hello-world", body: { name: "Ruby" })
puts result[:data]

# Different HTTP methods
client.functions.invoke("my-function", method: :get)
client.functions.invoke("my-function", method: :put, body: { key: "value" })

# Region routing
client.functions.invoke("my-function", body: { data: 1 }, region: :us_east_1)
```

## Error Handling

All methods return a `{ data:, error: }` hash:

```ruby
result = client.from("posts").select("*").execute

if result[:error]
  puts "Error: #{result[:error].message}"
else
  puts "Data: #{result[:data]}"
end
```

Each module has its own error hierarchy:

| Module | Base Error | Subclasses |
|--------|-----------|------------|
| PostgREST | `PostgrestError` | _(single class with message, details, hint, code)_ |
| Auth | `AuthError` | `AuthApiError`, `AuthRetryableFetchError`, `AuthUnknownError`, `AuthSessionMissingError`, `AuthWeakPasswordError`, `AuthPKCEGrantCodeExchangeError` |
| Storage | `StorageError` | `StorageApiError`, `StorageUnknownError` |
| Functions | `FunctionsError` | `FunctionsFetchError`, `FunctionsRelayError`, `FunctionsHttpError` |
| Realtime | `RealtimeError` | `RealtimeConnectionError`, `RealtimeSubscriptionError`, `RealtimeApiError` |

## Configuration

### Third-Party Auth Mode

Use your own auth provider instead of Supabase Auth:

```ruby
client = Supabase.create_client(
  "https://your-project.supabase.co",
  "your-anon-key",
  access_token: -> { my_auth_provider.get_token }
)

# client.auth will raise AuthNotAvailableError in this mode
```

### Custom Headers

```ruby
client = Supabase.create_client(
  "https://your-project.supabase.co",
  "your-anon-key",
  global: { headers: { "X-Custom-Header" => "value" } }
)
```

### Schema Selection

```ruby
# Default schema
client = Supabase.create_client(url, key, db: { schema: "my_schema" })

# Per-query schema
client.schema("other_schema").from("table").select("*").execute
```

## Requirements

- Ruby >= 3.1
- [Faraday](https://github.com/lostisland/faraday) ~> 2.0 (HTTP)
- [websocket-client-simple](https://github.com/shokai/websocket-client-simple) ~> 0.8 (Realtime)

## Gem Documentation

Each gem has its own README with detailed API documentation:

- [supabase-auth](gems/supabase-auth/README.md) - Authentication (GoTrue)
- [supabase-postgrest](gems/supabase-postgrest/README.md) - Database queries
- [supabase-realtime](gems/supabase-realtime/README.md) - Real-time subscriptions
- [supabase-storage](gems/supabase-storage/README.md) - File storage
- [supabase-functions](gems/supabase-functions/README.md) - Edge Functions

## License

MIT
