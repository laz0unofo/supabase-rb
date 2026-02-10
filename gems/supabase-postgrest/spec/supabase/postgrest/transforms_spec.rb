# frozen_string_literal: true

RSpec.describe "PostgREST Transforms" do
  let(:base_url) { "http://localhost:3000/rest/v1" }
  let(:client) { Supabase::PostgREST::Client.new(url: base_url, headers: {}) }

  def select_builder
    client.from("users").select
  end

  # ---------------------------------------------------------------------------
  # TR: Transform Tests
  # ---------------------------------------------------------------------------

  it "TR-01: order ascending by default" do
    builder = select_builder.order("name")
    expect(builder.url.query).to include("order=name.asc")
  end

  it "TR-02: order descending" do
    builder = select_builder.order("created_at", ascending: false)
    expect(builder.url.query).to include("order=created_at.desc")
  end

  it "TR-03: order with nulls_first: true" do
    builder = select_builder.order("name", nulls_first: true)
    expect(builder.url.query).to include("order=name.asc.nullsfirst")
  end

  it "TR-04: order with nulls_first: false (nullslast)" do
    builder = select_builder.order("name", nulls_first: false)
    expect(builder.url.query).to include("order=name.asc.nullslast")
  end

  it "TR-05: order with referenced_table" do
    builder = select_builder.order("name", referenced_table: "posts")
    expect(builder.url.query).to include("posts.order=name.asc")
  end

  it "TR-06: multiple order calls append (comma-separated)" do
    builder = select_builder.order("created_at", ascending: false).order("name")
    expect(builder.url.query).to include("order=created_at.desc,name.asc")
  end

  it "TR-07: limit sets ?limit=N" do
    builder = select_builder.limit(10)
    expect(builder.url.query).to include("limit=10")
  end

  it "TR-08: limit with referenced_table" do
    builder = select_builder.limit(5, referenced_table: "posts")
    expect(builder.url.query).to include("posts.limit=5")
  end

  it "TR-09: range sets offset and limit" do
    builder = select_builder.range(0, 9)
    query = builder.url.query
    expect(query).to include("offset=0")
    expect(query).to include("limit=10")
  end

  it "TR-10: range with non-zero offset" do
    builder = select_builder.range(10, 19)
    query = builder.url.query
    expect(query).to include("offset=10")
    expect(query).to include("limit=10")
  end

  it "TR-11: range with referenced_table" do
    builder = select_builder.range(0, 4, referenced_table: "posts")
    query = builder.url.query
    expect(query).to include("posts.offset=0")
    expect(query).to include("posts.limit=5")
  end

  it "TR-12: single sets Accept header" do
    builder = select_builder.single
    expect(builder.headers["Accept"]).to eq("application/vnd.pgrst.object+json")
  end

  it "TR-13: maybe_single sets Accept header and unwraps single element" do
    stub = stub_request(:get, "#{base_url}/users?select=*")
           .with(headers: { "Accept" => "application/vnd.pgrst.object+json" })
           .to_return(status: 200, body: '[{"id":1}]', headers: { "content-type" => "application/json" })

    result = select_builder.maybe_single.execute
    expect(stub).to have_been_requested
    expect(result.data).to eq("id" => 1)
  end

  it "TR-14: maybe_single returns nil for empty array" do
    stub_request(:get, "#{base_url}/users?select=*")
      .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    result = select_builder.maybe_single.execute
    expect(result.data).to be_nil
  end

  it "TR-15: maybe_single raises error for multiple rows" do
    stub_request(:get, "#{base_url}/users?select=*")
      .to_return(status: 200, body: '[{"id":1},{"id":2}]', headers: { "content-type" => "application/json" })

    expect { select_builder.maybe_single.execute }
      .to raise_error(Supabase::PostgREST::PostgrestError) { |e|
        expect(e.code).to eq("PGRST116")
      }
  end

  it "TR-16: csv sets Accept: text/csv" do
    builder = select_builder.csv
    expect(builder.headers["Accept"]).to eq("text/csv")
  end

  it "TR-17: geojson sets Accept: application/geo+json" do
    builder = select_builder.geojson
    expect(builder.headers["Accept"]).to eq("application/geo+json")
  end

  # ---------------------------------------------------------------------------
  # Explain
  # ---------------------------------------------------------------------------
  describe "explain" do
    it "sets explain header with no options" do
      builder = select_builder.explain
      expect(builder.headers["Accept"]).to include('for="explain"')
    end

    it "explain with analyze: true" do
      builder = select_builder.explain(analyze: true)
      expect(builder.headers["Accept"]).to include("analyze")
    end

    it "explain with verbose: true" do
      builder = select_builder.explain(verbose: true)
      expect(builder.headers["Accept"]).to include("verbose")
    end

    it "explain with format: :json" do
      builder = select_builder.explain(format: :json)
      expect(builder.headers["Accept"]).to include("format=json")
    end

    it "explain with all options" do
      builder = select_builder.explain(
        analyze: true, verbose: true, settings: true, buffers: true, wal: true, format: :json
      )
      accept = builder.headers["Accept"]
      expect(accept).to include("analyze")
      expect(accept).to include("verbose")
      expect(accept).to include("settings")
      expect(accept).to include("buffers")
      expect(accept).to include("wal")
      expect(accept).to include("format=json")
    end
  end

  # ---------------------------------------------------------------------------
  # Rollback & Max Affected
  # ---------------------------------------------------------------------------
  describe "rollback" do
    it "appends Prefer: tx=rollback" do
      builder = select_builder.rollback
      expect(builder.headers["Prefer"]).to include("tx=rollback")
    end
  end

  describe "max_affected" do
    it "appends Prefer: handling=strict,max-affected=N" do
      builder = client.from("users").update({ name: "test" }).max_affected(5)
      expect(builder.headers["Prefer"]).to include("handling=strict,max-affected=5")
    end
  end
end
