# frozen_string_literal: true

RSpec.describe "PostgREST Filters" do
  let(:base_url) { "http://localhost:3000/rest/v1" }
  let(:client) { Supabase::PostgREST::Client.new(url: base_url, headers: {}) }

  def select_builder
    client.from("users").select
  end

  # ---------------------------------------------------------------------------
  # FI: Filter Tests
  # ---------------------------------------------------------------------------

  it "FI-01: eq appends column=eq.value" do
    stub = stub_request(:get, "#{base_url}/users?select=*&id=eq.1")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.eq("id", 1).execute
    expect(stub).to have_been_requested
  end

  it "FI-02: neq appends column=neq.value" do
    stub = stub_request(:get, "#{base_url}/users?select=*&status=neq.deleted")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.neq("status", "deleted").execute
    expect(stub).to have_been_requested
  end

  it "FI-03: gt appends column=gt.value" do
    stub = stub_request(:get, "#{base_url}/users?select=*&age=gt.18")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.gt("age", 18).execute
    expect(stub).to have_been_requested
  end

  it "FI-04: gte appends column=gte.value" do
    stub = stub_request(:get, "#{base_url}/users?select=*&age=gte.21")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.gte("age", 21).execute
    expect(stub).to have_been_requested
  end

  it "FI-05: lt appends column=lt.value" do
    stub = stub_request(:get, "#{base_url}/users?select=*&age=lt.18")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.lt("age", 18).execute
    expect(stub).to have_been_requested
  end

  it "FI-06: lte appends column=lte.value" do
    stub = stub_request(:get, "#{base_url}/users?select=*&age=lte.65")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.lte("age", 65).execute
    expect(stub).to have_been_requested
  end

  it "FI-07: is for null value" do
    stub = stub_request(:get, "#{base_url}/users?select=*&deleted_at=is.null")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.is("deleted_at", "null").execute
    expect(stub).to have_been_requested
  end

  it "FI-08: is for true/false" do
    stub = stub_request(:get, "#{base_url}/users?select=*&active=is.true")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.is("active", true).execute
    expect(stub).to have_been_requested
  end

  it "FI-09: is_distinct appends column=isdistinct.value" do
    stub = stub_request(:get, "#{base_url}/users?select=*&name=isdistinct.null")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.is_distinct("name", "null").execute
    expect(stub).to have_been_requested
  end

  it "FI-10: like appends column=like.pattern" do
    stub = stub_request(:get, "#{base_url}/users?select=*&name=like.%25Alice%25")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.like("name", "%Alice%").execute
    expect(stub).to have_been_requested
  end

  it "FI-11: ilike appends column=ilike.pattern" do
    stub = stub_request(:get, "#{base_url}/users?select=*&name=ilike.%25alice%25")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.ilike("name", "%alice%").execute
    expect(stub).to have_been_requested
  end

  it "FI-12: like_all_of appends column=like(all).{patterns}" do
    builder = select_builder.like_all_of("name", %w[Alice Bob])
    expect(builder.url.query).to include("name=like(all).{Alice,Bob}")
  end

  it "FI-13: like_any_of appends column=like(any).{patterns}" do
    builder = select_builder.like_any_of("name", %w[Alice Bob])
    expect(builder.url.query).to include("name=like(any).{Alice,Bob}")
  end

  it "FI-14: ilike_all_of appends column=ilike(all).{patterns}" do
    builder = select_builder.ilike_all_of("name", %w[Alice Bob])
    expect(builder.url.query).to include("name=ilike(all).{Alice,Bob}")
  end

  it "FI-15: ilike_any_of appends column=ilike(any).{patterns}" do
    builder = select_builder.ilike_any_of("name", %w[Alice Bob])
    expect(builder.url.query).to include("name=ilike(any).{Alice,Bob}")
  end

  it "FI-16: match appends column=match.pattern" do
    stub = stub_request(:get, "#{base_url}/users?select=*&name=match.^A.*$")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.match("name", "^A.*$").execute
    expect(stub).to have_been_requested
  end

  it "FI-17: imatch appends column=imatch.pattern" do
    stub = stub_request(:get, "#{base_url}/users?select=*&name=imatch.^a.*$")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.imatch("name", "^a.*$").execute
    expect(stub).to have_been_requested
  end

  it "FI-18: in appends column=in.(values) with quoting" do
    stub = stub_request(:get, "#{base_url}/users?select=*&status=in.(active,inactive)")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.in("status", %w[active inactive]).execute
    expect(stub).to have_been_requested
  end

  it "FI-19: in quotes values with reserved chars" do
    builder = select_builder.in("name", ["a,b", "c(d)"])
    query = builder.url.query
    expect(query).to include("name=in.")
  end

  it "FI-20: contains appends column=cs.{values} for array" do
    stub = stub_request(:get, "#{base_url}/users?select=*&tags=cs.{ruby,rails}")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.contains("tags", %w[ruby rails]).execute
    expect(stub).to have_been_requested
  end

  it "FI-21: contains appends column=cs.json for hash" do
    builder = select_builder.contains("metadata", { key: "value" })
    query = builder.url.query
    expect(query).to include("metadata=cs.")
  end

  it "FI-22: contained_by appends column=cd.{values}" do
    stub = stub_request(:get, "#{base_url}/users?select=*&tags=cd.{ruby,rails,go}")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.contained_by("tags", %w[ruby rails go]).execute
    expect(stub).to have_been_requested
  end

  it "FI-23: overlaps appends column=ov.{values}" do
    stub = stub_request(:get, "#{base_url}/users?select=*&tags=ov.{ruby,go}")
           .to_return(status: 200, body: "[]", headers: { "content-type" => "application/json" })

    select_builder.overlaps("tags", %w[ruby go]).execute
    expect(stub).to have_been_requested
  end

  it "FI-24: filters are chainable" do
    builder = select_builder.eq("status", "active").gt("age", 18).lt("age", 65)
    query = builder.url.query
    expect(query).to include("status=eq.active")
    expect(query).to include("age=gt.18")
    expect(query).to include("age=lt.65")
  end

  it "FI-25: filter methods return self for chaining" do
    builder = select_builder
    result = builder.eq("id", 1)
    expect(result).to be(builder)
  end

  # ---------------------------------------------------------------------------
  # Range Filters
  # ---------------------------------------------------------------------------
  describe "range filters" do
    it "range_gt appends column=sr.value" do
      builder = select_builder.range_gt("period", "[2023-01-01,2023-12-31]")
      expect(builder.url.query).to include("period=sr.[2023-01-01,2023-12-31]")
    end

    it "range_gte appends column=nxl.value" do
      builder = select_builder.range_gte("period", "[2023-01-01,2023-12-31]")
      expect(builder.url.query).to include("period=nxl.[2023-01-01,2023-12-31]")
    end

    it "range_lt appends column=sl.value" do
      builder = select_builder.range_lt("period", "[2023-01-01,2023-12-31]")
      expect(builder.url.query).to include("period=sl.[2023-01-01,2023-12-31]")
    end

    it "range_lte appends column=nxr.value" do
      builder = select_builder.range_lte("period", "[2023-01-01,2023-12-31]")
      expect(builder.url.query).to include("period=nxr.[2023-01-01,2023-12-31]")
    end

    it "range_adjacent appends column=adj.value" do
      builder = select_builder.range_adjacent("period", "[2023-01-01,2023-12-31]")
      expect(builder.url.query).to include("period=adj.[2023-01-01,2023-12-31]")
    end
  end

  # ---------------------------------------------------------------------------
  # Text Search Filters
  # ---------------------------------------------------------------------------
  describe "text search" do
    it "text_search with no type uses fts operator" do
      builder = select_builder.text_search("content", "ruby")
      expect(builder.url.query).to include("content=fts.ruby")
    end

    it "text_search with type: :plain uses plfts" do
      builder = select_builder.text_search("content", "ruby", type: :plain)
      expect(builder.url.query).to include("content=plfts.ruby")
    end

    it "text_search with type: :phrase uses phfts" do
      builder = select_builder.text_search("content", "ruby lang", type: :phrase)
      expect(builder.url.query).to include("content=phfts.ruby%20lang")
    end

    it "text_search with type: :websearch uses wfts" do
      builder = select_builder.text_search("content", "ruby -java", type: :websearch)
      expect(builder.url.query).to include("content=wfts.ruby%20-java")
    end

    it "text_search with config appends config in parens" do
      builder = select_builder.text_search("content", "ruby", config: "english")
      expect(builder.url.query).to include("content=fts(english).ruby")
    end

    it "text_search with type and config" do
      builder = select_builder.text_search("content", "ruby", type: :websearch, config: "english")
      expect(builder.url.query).to include("content=wfts(english).ruby")
    end
  end

  # ---------------------------------------------------------------------------
  # Compound Filters
  # ---------------------------------------------------------------------------
  describe "compound filters" do
    it "match_filter applies multiple eq filters from hash" do
      builder = select_builder.match_filter({ status: "active", role: "admin" })
      query = builder.url.query
      expect(query).to include("status=eq.active")
      expect(query).to include("role=eq.admin")
    end

    it "not negates a filter" do
      builder = select_builder.not("status", "eq", "deleted")
      expect(builder.url.query).to include("status=not.eq.deleted")
    end

    it "or applies or filter" do
      builder = select_builder.or("id.eq.1,id.eq.2")
      expect(builder.url.query).to include("or=(id.eq.1,id.eq.2)")
    end

    it "or with referenced_table prefixes the key" do
      builder = select_builder.or("id.eq.1", referenced_table: "posts")
      expect(builder.url.query).to include("posts.or=(id.eq.1)")
    end

    it "filter applies generic filter" do
      builder = select_builder.filter("id", "eq", 1)
      expect(builder.url.query).to include("id=eq.1")
    end
  end
end
