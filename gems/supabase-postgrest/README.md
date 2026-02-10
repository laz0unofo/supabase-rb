# Supabase PostgREST (Ruby)

Ruby client for [PostgREST](https://postgrest.org). Build type-safe database queries with a chainable, ORM-like interface.

## Installation

```ruby
gem "supabase-postgrest"
```

## Usage

```ruby
require "supabase/postgrest"

client = Supabase::PostgREST::Client.new(
  url: "https://your-project.supabase.co/rest/v1",
  headers: { "apikey" => "your-key", "Authorization" => "Bearer your-key" }
)

result = client.from("posts")
  .select("id, title, author:users(name)")
  .eq("published", true)
  .order("created_at", ascending: false)
  .limit(10)
  .execute

puts result[:data]
```

## API Reference

### `Supabase::PostgREST::Client`

#### `initialize(url:, headers: {}, schema: nil, fetch: nil, timeout: nil)`

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `url` | String | _(required)_ | PostgREST base URL |
| `headers` | Hash | `{}` | Default headers |
| `schema` | String | `nil` | Default PostgreSQL schema |
| `fetch` | Proc | `nil` | Custom Faraday connection factory |
| `timeout` | Integer | `nil` | Request timeout in seconds |

#### `from(relation) -> QueryBuilder`

Returns a query builder scoped to a table or view. Each call returns an independent instance.

```ruby
client.from("users")   # scoped to "users" table
client.from("my_view") # scoped to a view
```

#### `schema(name) -> Client`

Returns a new client targeting a different PostgreSQL schema.

```ruby
client.schema("private").from("secrets").select("*").execute
```

#### `rpc(function_name, args: {}, head: false, get: false, count: nil) -> Hash`

Calls a stored procedure / remote function.

```ruby
# POST (default)
client.rpc("get_total_posts", args: { status: "published" })

# GET (args as query params)
client.rpc("get_total_posts", args: { status: "published" }, get: true)

# HEAD (count only)
client.rpc("get_total_posts", head: true, count: :exact)
```

### CRUD Operations

All CRUD methods return a `FilterBuilder` for chaining filters and transforms.

#### `select(columns = "*", head: false, count: nil) -> FilterBuilder`

```ruby
client.from("posts").select("*").execute
client.from("posts").select("id, title").execute
client.from("posts").select("*, author:users(name)").execute  # joins
client.from("posts").select("*", count: :exact).execute       # with count
client.from("posts").select("*", head: true).execute          # count only, no data
```

#### `insert(values, count: nil, default_to_null: true) -> FilterBuilder`

```ruby
# Single row
client.from("posts").insert({ title: "Hello", body: "World" }).execute

# Bulk insert
client.from("posts").insert([
  { title: "First" },
  { title: "Second" }
]).execute

# Return inserted data
client.from("posts").insert({ title: "Hello" }).select("id, title").execute

# Missing columns default to actual DB defaults (not NULL)
client.from("posts").insert({ title: "Hello" }, default_to_null: false).execute
```

#### `update(values, count: nil) -> FilterBuilder`

```ruby
client.from("posts").update({ published: true }).eq("id", 1).execute
```

#### `upsert(values, on_conflict: nil, ignore_duplicates: false, count: nil, default_to_null: true) -> FilterBuilder`

```ruby
client.from("posts").upsert({ id: 1, title: "Updated" }, on_conflict: "id").execute

# Ignore duplicates instead of merging
client.from("posts").upsert(
  [{ id: 1, title: "A" }, { id: 2, title: "B" }],
  on_conflict: "id",
  ignore_duplicates: true
).execute
```

#### `delete(count: nil) -> FilterBuilder`

```ruby
client.from("posts").delete.eq("id", 1).execute
```

### Filter Methods

All filter methods return `self` for chaining.

#### Comparison

```ruby
.eq("column", value)       # column = value
.neq("column", value)      # column != value
.gt("column", value)       # column > value
.gte("column", value)      # column >= value
.lt("column", value)       # column < value
.lte("column", value)      # column <= value
```

#### Null / Boolean

```ruby
.is("column", nil)         # column IS NULL
.is("column", true)        # column IS TRUE
.is_distinct("column", nil) # column IS DISTINCT FROM NULL
```

#### Pattern Matching

```ruby
.like("column", "%pattern%")     # LIKE
.ilike("column", "%pattern%")    # ILIKE (case-insensitive)
.like_all_of("column", ["%a%", "%b%"])  # LIKE ALL
.like_any_of("column", ["%a%", "%b%"])  # LIKE ANY
.ilike_all_of("column", ["%a%", "%b%"]) # ILIKE ALL
.ilike_any_of("column", ["%a%", "%b%"]) # ILIKE ANY
```

#### Regex

```ruby
.match("column", "^pattern$")   # ~ (POSIX regex)
.imatch("column", "^pattern$")  # ~* (case-insensitive)
```

#### Collections

```ruby
.in("column", [1, 2, 3])            # column IN (1, 2, 3)
.contains("column", ["a", "b"])      # column @> {a,b}
.contained_by("column", ["a", "b"])  # column <@ {a,b}
.overlaps("column", ["a", "b"])      # column && {a,b}
```

#### Range

```ruby
.range_gt("column", "[1,5]")      # column >> [1,5]
.range_gte("column", "[1,5]")     # column &> [1,5]
.range_lt("column", "[1,5]")      # column << [1,5]
.range_lte("column", "[1,5]")     # column <& [1,5]
.range_adjacent("column", "[1,5]") # column -|- [1,5]
```

#### Full-Text Search

```ruby
.text_search("column", "query")                           # tsvector @@ tsquery
.text_search("column", "query", type: :plain)             # plainto_tsquery
.text_search("column", "query", type: :phrase)             # phraseto_tsquery
.text_search("column", "query", type: :websearch)          # websearch_to_tsquery
.text_search("column", "query", config: "english")         # with language config
```

#### Compound Filters

```ruby
.match_filter({ column1: "value1", column2: "value2" })   # multiple eq
.not("column", "eq", "value")                              # NOT column = value
.or("col1.eq.a,col2.eq.b")                                # col1 = a OR col2 = b
.or("col1.eq.a", referenced_table: "other")               # on referenced table
.filter("column", "eq", "value")                           # generic filter
```

### Transform Methods

#### Ordering and Pagination

```ruby
.order("created_at", ascending: false)                  # ORDER BY created_at DESC
.order("name", ascending: true, nulls_first: false)     # NULLS LAST
.order("name", referenced_table: "author")              # order on joined table
.limit(10)                                              # LIMIT 10
.limit(5, referenced_table: "comments")                 # limit on joined table
.range(0, 9)                                            # rows 0-9 (inclusive)
```

#### Response Shaping

```ruby
.single         # expect exactly 1 row; returns object (not array)
.maybe_single   # expect 0 or 1 row; returns object or nil
.csv            # response as CSV text
.geojson        # response as GeoJSON
```

#### Query Analysis

```ruby
.explain(analyze: true, verbose: true, format: :json)
```

#### Transaction Control

```ruby
.rollback                   # roll back the transaction
.max_affected(100)          # fail if > 100 rows affected
```

#### Exception Mode

```ruby
# Raises PostgrestError instead of returning in result hash
client.from("posts").select("*").throw_on_error.execute
```

### Result Format

All operations return:

```ruby
{
  data: <parsed response>,
  error: <PostgrestError or nil>,
  count: <integer or nil>,
  status: <HTTP status code>,
  status_text: <HTTP status text>
}
```
