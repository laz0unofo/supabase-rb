## Codebase Patterns
- Use `eval "$(rbenv init -)"` before running Ruby commands to ensure Ruby 3.3.0 is active (system Ruby is 2.6)
- Root Rakefile runs all gem specs via `bundle exec rake spec` with `-I gems/{name}/spec -I gems/{name}/lib` for proper load paths
- Each gem follows pattern: `gems/{name}/lib/supabase/{module}.rb` requires `{module}/version`
- VERSION constant lives at `Supabase::{Module}::VERSION` (top-level gem uses `Supabase::VERSION`)
- Gemspecs are excluded from rubocop via `**/*.gemspec` in `.rubocop.yml`
- HTTP gems depend on `faraday ~> 2.0`, WebSocket gem depends on `websocket-client-simple ~> 0.8`
- No cross-gem runtime dependencies (except top-level `supabase` gem which depends on all 5)
- All specs use webmock for HTTP stubbing
- `.rspec` files in each gem directory with `--require spec_helper`
- Rubocop ClassLength limit is 100 lines; extract modules to keep classes small
- Use `**options` keyword splat for methods with >5 params to satisfy `Metrics/ParameterLists`
- All client methods return `{ data:, error: }` result hashes (never raise by default)
- Error hierarchy pattern: BaseError < StandardError, then specific subclasses with `status:` and `context:` attrs
- Test files go in `gems/{name}/spec/supabase/{module}/` subdirectories (e.g., `client_spec.rb`)
- WebMock: do NOT chain multiple `.to_return` on same stub (they cycle sequentially); use one `stub_request(...).to_return(...)` per test
- Rubocop `Naming/VariableNumber`: use normalcase for symbol numbers (`:ap_southeast1` not `:ap_southeast_1`)
- Faraday test adapter blocks must be multiline `do...end`, not single-line, to satisfy `Style/BlockDelimiters`

---

## 2026-02-10 - US-001
- What was implemented: Multi-gem monorepo scaffolding with 6 gems (supabase, supabase-auth, supabase-postgrest, supabase-realtime, supabase-storage, supabase-functions)
- Files changed:
  - Root: Gemfile, Gemfile.lock, Rakefile, .rubocop.yml, .rspec, .ruby-version, .gitignore
  - Per gem (x6): gemspec, Gemfile, .rspec, lib/{module}.rb, lib/{module}/version.rb, spec/spec_helper.rb, spec/{module}_spec.rb
- **Learnings for future iterations:**
  - System Ruby is 2.6; must use rbenv with `eval "$(rbenv init -)"` to get Ruby 3.3.0
  - Root `*.gemspec` glob only matches root-level gemspecs; use `**/*.gemspec` to exclude nested ones
  - Running rspec from root requires explicit `-I` flags for each gem's spec and lib dirs
  - Bundler resolves all 6 gemspecs from the root Gemfile via `gemspec path:` directives
---

## 2026-02-10 - US-002
- What was implemented: Functions Client core with error hierarchy, body auto-serialization, response parsing, region routing, header precedence, and all HTTP methods
- Files changed:
  - `gems/supabase-functions/lib/supabase/functions.rb` (added requires for errors, client)
  - `gems/supabase-functions/lib/supabase/functions/errors.rb` (new: FunctionsError, FunctionsFetchError, FunctionsRelayError, FunctionsHttpError)
  - `gems/supabase-functions/lib/supabase/functions/client.rb` (new: Client class with invoke, set_auth, body/response handling)
  - `gems/supabase-functions/lib/supabase/functions/response_handler.rb` (new: extracted response processing module)
  - `.chief/prds/main/prd.json` (marked US-002 as passes: true)
- **Learnings for future iterations:**
  - Rubocop ClassLength limit is 100 lines; extract modules (e.g., ResponseHandler) to keep classes under limit
  - `Naming/AccessorMethodName` cop flags `set_*` methods; use `rubocop:disable` inline when matching external API conventions (e.g., Supabase JS client's `set_auth`)
  - `invoke` uses `**options` keyword splat instead of 6 positional params to avoid `Metrics/ParameterLists` cop
  - Rescue specific exceptions (`Faraday::Error, IOError`) instead of broad `StandardError` to avoid `Lint/DuplicateBranch`
  - Response handler: `text/event-stream` returns raw Faraday response object (not body) per Supabase spec
---

## 2026-02-10 - US-003
- What was implemented: Comprehensive test suite for the Functions client (64 tests total)
- Files changed:
  - `gems/supabase-functions/spec/supabase/functions/client_spec.rb` (new: 64 tests covering all acceptance criteria)
  - `.chief/prds/main/prd.json` (marked US-003 as passes: true)
- **Test coverage areas:**
  - AU-01 through AU-05: Authentication / set_auth persistence
  - BH-01 through BH-08: Body auto-detection and serialization (String, Hash, Array, IO, StringIO, nil, nested, empty)
  - RP-01 through RP-08: Response parsing (JSON, JSON array, text/plain, octet-stream, event-stream, charset, unknown, missing)
  - EH-01 through EH-08: Error handling (HttpError, RelayError, FetchError, network, timeout, context)
  - RR-01 through RR-05: Region routing (default :any, client-level, invoke-level override, :any override, symbol conversion)
  - TC-01 through TC-05: Timeout behavior (default, per-request, expiry, custom fetch with/without timeout)
  - HP-01 through HP-03: Header precedence (invoke > client > auto-detected)
  - HM-01 through HM-05: HTTP methods (POST, GET, PUT, PATCH, DELETE)
  - Error hierarchy tests, constructor tests, invalid method test, 5 integration scenarios
- **Learnings for future iterations:**
  - WebMock `.to_return` calls are additive (cycle through responses); never chain a helper that calls `.to_return` with another `.to_return`
  - Use direct `stub_request(:method, url).to_return(...)` in each test for clarity; avoid helpers with default responses
  - Rubocop `Naming/VariableNumber` applies to symbols too: `:ap_southeast1` not `:ap_southeast_1`
  - Faraday test adapter: use multiline `do...end` blocks to satisfy `Style/BlockDelimiters` and `Style/SingleLineDoEndBlock`
---
