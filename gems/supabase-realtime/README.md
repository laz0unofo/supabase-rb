# Supabase Realtime (Ruby)

Ruby client for [Supabase Realtime](https://supabase.com/docs/guides/realtime). Subscribe to broadcast messages, presence events, and PostgreSQL database changes over WebSocket.

## Installation

```ruby
gem "supabase-realtime"
```

## Usage

```ruby
require "supabase/realtime"

client = Supabase::Realtime::Client.new(
  "wss://your-project.supabase.co/realtime/v1",
  params: { apikey: "your-key" }
)

channel = client.channel("room1")
channel.on_broadcast("message") do |payload|
  puts "Received: #{payload}"
end
channel.subscribe { |status| puts "Subscribed: #{status}" }

client.connect
```

## API Reference

### `Supabase::Realtime::Client`

#### `initialize(url, **options)`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `url` | String | _(required)_ | Realtime WebSocket URL |
| `params` | Hash | _(required)_ | Must include `:apikey` |
| `timeout` | Integer | `10_000` | Connection timeout (ms) |
| `heartbeat_interval_ms` | Integer | `25_000` | Heartbeat interval (ms) |
| `reconnect_after_ms` | Integer | `nil` | Custom reconnect delay (exponential backoff by default) |
| `logger` | Logger | `nil` | Logger instance |
| `access_token` | String | `nil` | Initial JWT access token |

#### `connect`

Establishes the WebSocket connection. Automatically handles heartbeat and reconnection.

#### `disconnect`

Closes the WebSocket connection gracefully.

#### `channel(name, config: {}) -> RealtimeChannel`

Creates a new channel for the given topic.

```ruby
channel = client.channel("room1")
channel = client.channel("chat", config: { broadcast: { self: true } })
```

#### `set_auth(token)`

Updates the access token for all channels.

```ruby
client.set_auth("new-jwt-token")
```

#### `get_channels -> Array<RealtimeChannel>`

Returns a copy of all active channels.

#### `remove_channel(channel)`

Unsubscribes and removes a channel.

#### `remove_all_channels`

Unsubscribes and removes all channels.

### `Supabase::Realtime::RealtimeChannel`

#### States

`:closed` -> `:joining` -> `:joined` -> `:leaving` -> `:closed`

#### `subscribe { |status| } -> self`

Joins the channel. The callback fires when the subscription succeeds.

```ruby
channel.subscribe do |status|
  puts "Channel status: #{status}"
end
```

#### `unsubscribe -> self`

Leaves the channel.

### Broadcast

Send and receive ephemeral messages between clients.

#### `on_broadcast(event, &callback) -> self`

Registers a listener for broadcast messages matching the given event.

```ruby
channel.on_broadcast("cursor_move") do |payload|
  puts "Cursor: x=#{payload["x"]}, y=#{payload["y"]}"
end
```

#### `send_broadcast(event:, payload: {}, type: :websocket)`

Sends a broadcast message to all subscribers.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `event` | String | _(required)_ | Event name |
| `payload` | Hash | `{}` | Message payload |
| `type` | Symbol | `:websocket` | Transport: `:websocket` or `:http` |

```ruby
channel.send_broadcast(event: "cursor_move", payload: { x: 100, y: 200 })

# HTTP fallback (useful when not connected)
channel.send_broadcast(event: "notification", payload: { text: "Hello" }, type: :http)
```

### Presence

Track and synchronize shared state across clients.

#### `on_presence(event, &callback) -> self`

Registers a presence event listener.

| Event | Description |
|-------|-------------|
| `:sync` | Presence state fully synchronized |
| `:join` | A user joined |
| `:leave` | A user left |

```ruby
channel.on_presence(:sync) { puts "Presence synced" }
channel.on_presence(:join) { |data| puts "Joined: #{data}" }
channel.on_presence(:leave) { |data| puts "Left: #{data}" }
```

#### `track(payload)`

Starts tracking presence with the given payload.

```ruby
channel.track({ user_id: "user1", online_at: Time.now.iso8601 })
```

#### `untrack`

Stops tracking presence for this client.

#### `presence`

Returns the `Presence` object for querying current state.

### PostgreSQL Changes (CDC)

Listen to real-time database changes via Change Data Capture.

#### `on_postgres_changes(event:, schema: "public", table: nil, filter: nil, &callback) -> self`

Registers a listener for database changes.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `event` | Symbol | _(required)_ | `:insert`, `:update`, `:delete`, or `:all` |
| `schema` | String | `"public"` | PostgreSQL schema |
| `table` | String | `nil` | Table name (all tables if nil) |
| `filter` | String | `nil` | Filter expression (e.g., `"id=eq.1"`) |

```ruby
# Listen to all inserts on the posts table
channel.on_postgres_changes(event: :insert, schema: "public", table: "posts") do |payload|
  puts "New post: #{payload}"
end

# Listen to all changes on any table
channel.on_postgres_changes(event: :all, schema: "public") do |payload|
  puts "Change: #{payload}"
end

# Filtered changes
channel.on_postgres_changes(
  event: :update,
  schema: "public",
  table: "orders",
  filter: "status=eq.pending"
) do |payload|
  puts "Order updated: #{payload}"
end
```

## Connection Lifecycle

The client manages:

- **Heartbeat**: Sent every 25s (configurable) to keep the connection alive. Missed heartbeat triggers reconnect.
- **Reconnection**: Exponential backoff (1s, 2s, 5s, 10s cap). All previously joined channels are automatically rejoined.
- **Send buffer**: Messages are queued when disconnected and flushed upon reconnection.
- **Message routing**: Incoming messages are routed to the correct channel by topic.

## Error Hierarchy

| Error Class | When |
|------------|------|
| `RealtimeError` | Base class |
| `RealtimeConnectionError` | WebSocket connection failures |
| `RealtimeSubscriptionError` | Channel join/subscription errors |
| `RealtimeApiError` | API-level errors |
