# Supabase Storage (Ruby)

Ruby client for [Supabase Storage](https://supabase.com/docs/guides/storage). Upload, download, and manage files with support for signed URLs, public URLs, and image transforms.

## Installation

```ruby
gem "supabase-storage"
```

## Usage

```ruby
require "supabase/storage"

client = Supabase::Storage::Client.new(
  url: "https://your-project.supabase.co/storage/v1",
  headers: { "apikey" => "your-key", "Authorization" => "Bearer your-key" }
)

# Upload a file
bucket = client.from("avatars")
bucket.upload("user1/photo.png", File.open("photo.png"), content_type: "image/png")

# Get a public URL
url = bucket.get_public_url("user1/photo.png")[:data][:public_url]
```

## API Reference

### `Supabase::Storage::Client`

#### `initialize(url:, headers: {}, fetch: nil)`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `url` | String | _(required)_ | Storage service base URL |
| `headers` | Hash | `{}` | Default headers |
| `fetch` | Proc | `nil` | Custom Faraday connection factory |

#### `from(bucket_id) -> StorageFileApi`

Returns a file API scoped to the given bucket.

```ruby
bucket = client.from("my-bucket")
```

### Bucket Management

#### `list_buckets(**options) -> Hash`

Lists all buckets. Options: `limit:`, `offset:`, `sort_by:`, `search:`.

#### `get_bucket(id) -> Hash`

Gets bucket details by ID.

#### `create_bucket(id, **options) -> Hash`

Creates a new bucket. Options: `public:`, `file_size_limit:`, `allowed_mime_types:`.

```ruby
client.create_bucket("my-bucket", public: true, file_size_limit: 5_242_880)
```

#### `update_bucket(id, **options) -> Hash`

Updates bucket settings. Options: `public:`, `file_size_limit:`, `allowed_mime_types:`.

#### `empty_bucket(id) -> Hash`

Removes all files from a bucket.

#### `delete_bucket(id) -> Hash`

Deletes a bucket (must be empty first).

### File Operations (`StorageFileApi`)

#### `upload(path, body, **options) -> Hash`

Uploads a file to storage.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cache_control` | String | `"3600"` | Cache-Control header value |
| `content_type` | String | `"application/octet-stream"` | MIME type |
| `upsert` | Boolean | `false` | Overwrite if exists |
| `metadata` | Hash | `nil` | Custom metadata |

```ruby
# Upload from file
bucket.upload("docs/report.pdf", File.open("report.pdf"), content_type: "application/pdf")

# Upload string content
bucket.upload("notes/hello.txt", "Hello, World!", content_type: "text/plain")

# Upsert (overwrite)
bucket.upload("photo.png", file_io, upsert: true)
```

#### `update(path, body, **options) -> Hash`

Replaces an existing file. Same options as `upload`.

#### `download(path, transform: nil) -> Hash`

Downloads a file. Returns binary data in `data`.

```ruby
result = bucket.download("photo.png")
File.write("local.png", result[:data])

# With image transform
result = bucket.download("photo.png", transform: { width: 200, height: 200 })
```

#### `move(from_path, to_path, destination_bucket: nil) -> Hash`

Moves a file to a new path (optionally to a different bucket).

```ruby
bucket.move("old/path.png", "new/path.png")
bucket.move("file.png", "file.png", destination_bucket: "other-bucket")
```

#### `copy(from_path, to_path, destination_bucket: nil) -> Hash`

Copies a file to a new path.

#### `remove(paths) -> Hash`

Deletes one or more files.

```ruby
bucket.remove(["file1.png", "file2.png"])
```

#### `info(path) -> Hash`

Returns file metadata (size, content type, creation date, etc.).

#### `exists?(path) -> Hash`

Checks if a file exists. Returns `{ data: true/false, error: nil }`.

### URL Operations

#### `get_public_url(path, download: nil, transform: nil) -> Hash`

Generates a public URL synchronously (no HTTP call).

```ruby
result = bucket.get_public_url("photo.png")
url = result[:data][:public_url]

# With download filename
result = bucket.get_public_url("photo.png", download: "my-photo.png")

# With image transform
result = bucket.get_public_url("photo.png", transform: { width: 100, height: 100, resize: "cover" })
```

#### `create_signed_url(path, expires_in, download: nil, transform: nil) -> Hash`

Creates a time-limited signed URL.

```ruby
result = bucket.create_signed_url("private/doc.pdf", 3600)  # 1 hour
url = result[:data][:signed_url]
```

#### `create_signed_urls(paths, expires_in, download: nil) -> Hash`

Creates multiple signed URLs in a single request.

```ruby
result = bucket.create_signed_urls(["file1.png", "file2.png"], 3600)
urls = result[:data]  # [{ path:, signed_url:, error: }, ...]
```

#### `create_signed_upload_url(path, upsert: false) -> Hash`

Creates a signed URL for client-side uploads.

```ruby
result = bucket.create_signed_upload_url("uploads/file.png")
# => { data: { signed_url:, token:, path: }, error: nil }
```

#### `upload_to_signed_url(path, token, body, **options) -> Hash`

Uploads a file using a previously created signed upload URL.

#### `list(path = nil, **options) -> Hash`

Lists files in a bucket directory.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `limit` | Integer | `100` | Max results |
| `offset` | Integer | `0` | Pagination offset |
| `sort_by` | Hash | `{ column: "name", order: "asc" }` | Sort configuration |
| `search` | String | `nil` | Search query |

```ruby
result = bucket.list("photos/", limit: 50, sort_by: { column: "created_at", order: "desc" })
files = result[:data]
```

### Image Transforms

Available transform parameters for `download`, `get_public_url`, `create_signed_url`:

| Parameter | Type | Description |
|-----------|------|-------------|
| `width` | Integer | Target width |
| `height` | Integer | Target height |
| `resize` | String | Resize mode: `"cover"`, `"contain"`, `"fill"` |
| `quality` | Integer | Quality (1-100) |
| `format` | String | Output format: `"origin"`, `"avif"` |

## Error Hierarchy

| Error Class | When |
|------------|------|
| `StorageError` | Base class |
| `StorageApiError` | Non-2xx HTTP responses |
| `StorageUnknownError` | Network failures, timeouts |
