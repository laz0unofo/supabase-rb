## Codebase Patterns
- Each sub-gem is standalone (no dependency on core `supabase` gem). Use `unless defined?(Supabase::Error)` guards to define base error classes inline.
- Use `unless ... end` block form (not postfix modifier) for multiline class definitions to satisfy rubocop `Style/MultilineIfModifier`.
- Existing tests check `superclass` equality and `is_a?` relationships - preserve transitive inheritance chains when re-parenting error classes.
- Sub-errors within each gem should inherit from their gem's base error (e.g., `StorageApiError < StorageError`) to preserve `is_a?` checks in existing tests. Deeper reorganization (e.g., `StorageApiError < Supabase::ApiError`) happens in gem-specific stories.
- Commit format: `feat: [US-XXX] - Story Title`

---

## 2026-02-10 - US-001
- Implemented unified `Supabase::Error`, `Supabase::ApiError`, and `Supabase::NetworkError` base classes in the core supabase gem
- Added `SupabaseError = Error` alias for backward compatibility
- All 5 sub-gem error files updated to inherit their base error from `Supabase::Error` (with `unless defined?` guards for standalone usage)
- Preserved all existing sub-error inheritance chains within each gem
- Updated 2 test files that checked `.superclass == StandardError` (PostgREST, Functions)
- Added comprehensive errors_spec.rb in the core supabase gem covering all base classes, aliases, cross-gem hierarchy, and attribute preservation
- Files changed:
  - `gems/supabase/lib/supabase/errors.rb` (new: Error, ApiError, NetworkError, SupabaseError alias)
  - `gems/supabase-auth/lib/supabase/auth/errors.rb` (AuthError < Supabase::Error)
  - `gems/supabase-storage/lib/supabase/storage/errors.rb` (StorageError < Supabase::Error)
  - `gems/supabase-postgrest/lib/supabase/postgrest/errors.rb` (PostgrestError < Supabase::Error)
  - `gems/supabase-functions/lib/supabase/functions/errors.rb` (FunctionsError < Supabase::Error)
  - `gems/supabase-realtime/lib/supabase/realtime/errors.rb` (RealtimeError < Supabase::Error)
  - `gems/supabase/spec/supabase/errors_spec.rb` (new test file)
  - `gems/supabase-postgrest/spec/supabase/postgrest/errors_spec.rb` (updated superclass check)
  - `gems/supabase-functions/spec/supabase/functions/client_spec.rb` (updated superclass check)
- **Learnings for future iterations:**
  - The `unless defined?` guard pattern must use block form (`unless ... end`) not postfix modifier to satisfy rubocop
  - Changing parent classes breaks `is_a?` checks and `superclass` equality tests - always grep for these before changing inheritance
  - Sub-gems can be tested standalone or via root Gemfile; both paths must work
  - The deeper hierarchy reorganization (e.g., `AuthApiError < Supabase::ApiError`) should be done in the gem-specific stories (US-002 through US-005) along with corresponding test updates
---

## 2026-02-10 - US-002
- Converted all Auth client methods from `{ data:, error: }` hash returns to direct data returns with exception raising
- Error hierarchy updated: `AuthApiError < Supabase::ApiError`, `AuthRetryableFetchError < Supabase::NetworkError`, `AuthUnknownError < Supabase::ApiError`
- `AuthError` converted from class to module (mixin) so `is_a?(AuthError)` still works across all auth error classes regardless of parent
- `AuthBaseError < Supabase::Error` added as concrete base class for non-HTTP/non-network auth errors
- `HttpHandler#request` now raises classified errors instead of returning `{ data: nil, error: }` hashes
- `HttpHandler#classify_and_return` returns parsed data directly, raises on error
- Removed all `result[:error]` early-return propagation from: `sign_in_methods.rb`, `sign_up_methods.rb`, `session_methods.rb`, `user_methods.rb`, `verify_methods.rb`, `mfa_methods.rb`, `mfa_api.rb`, `admin_api.rb`, `client.rb`
- `session_helpers.rb#refresh_access_token` returns Session object directly instead of `{ data: { session: }, error: nil }`
- All 7 spec files updated: replaced `result[:data][:key]` with `result[:key]`, `result[:error]` checks with `raise_error` matchers
- 157 specs pass, 0 rubocop offenses
- Files changed (20 files, -123 lines net):
  - `gems/supabase-auth/lib/supabase/auth/errors.rb` (AuthError -> module, AuthBaseError, re-parented ApiError/NetworkError subclasses)
  - `gems/supabase-auth/lib/supabase/auth/http_handler.rb` (raise instead of return)
  - `gems/supabase-auth/lib/supabase/auth/sign_in_methods.rb` (return data directly)
  - `gems/supabase-auth/lib/supabase/auth/sign_up_methods.rb` (return data directly, raise on validation)
  - `gems/supabase-auth/lib/supabase/auth/session_methods.rb` (raise on missing session/invalid token)
  - `gems/supabase-auth/lib/supabase/auth/session_helpers.rb` (return Session directly)
  - `gems/supabase-auth/lib/supabase/auth/verify_methods.rb` (return data directly)
  - `gems/supabase-auth/lib/supabase/auth/user_methods.rb` (raise on missing session)
  - `gems/supabase-auth/lib/supabase/auth/mfa_methods.rb` (raise on missing session)
  - `gems/supabase-auth/lib/supabase/auth/mfa_api.rb` (return data directly, no error hash checks)
  - `gems/supabase-auth/lib/supabase/auth/admin_api.rb` (return data directly)
  - `gems/supabase-auth/lib/supabase/auth/client.rb` (get_session/get_user return data directly)
  - `gems/supabase-auth/spec/supabase/auth/sign_in_spec.rb`
  - `gems/supabase-auth/spec/supabase/auth/sign_up_spec.rb`
  - `gems/supabase-auth/spec/supabase/auth/session_spec.rb`
  - `gems/supabase-auth/spec/supabase/auth/mfa_spec.rb`
  - `gems/supabase-auth/spec/supabase/auth/admin_spec.rb`
  - `gems/supabase-auth/spec/supabase/auth/client_spec.rb`
  - `gems/supabase-auth/spec/supabase/auth/utilities_spec.rb` (AuthError.new -> AuthBaseError.new)
- **Learnings:**
  - When re-parenting error classes across different base hierarchies, use a module mixin to preserve `is_a?` type checks
  - `AuthError` as a module allows classes to inherit from `Supabase::ApiError`/`Supabase::NetworkError` while still being identifiable as auth errors
  - The ErrorClassifier itself didn't need changes - it already returned error objects; the key was making HttpHandler raise them
---

## 2026-02-10 - US-003
- Converted all Storage client methods from `{ data:, error: }` hash returns to direct data returns with exception raising
- Error hierarchy updated: `StorageApiError < Supabase::ApiError`, `StorageUnknownError < Supabase::NetworkError`
- `StorageError` converted from class to module (mixin) so `is_a?(StorageError)` still works across all storage error classes
- `StorageBaseError < Supabase::Error` added as concrete base class for non-HTTP/non-network storage errors
- `handle_response` now calls `raise_on_error` + returns parsed JSON directly
- Removed `api_error_result` and `unknown_error_result` helpers
- All `rescue Faraday::Error` blocks now `raise StorageUnknownError` instead of returning hash
- Special handling preserved: `download` returns raw `response.body`, `exists?` returns boolean
- `get_public_url` returns `{ public_url: }` directly (no HTTP call, never errors)
- All 4 spec files updated: `result[:data][:key]` -> `result[:key]`, error checks -> `raise_error` matchers
- Used `raise_error(Class, message) { |e| ... }` pattern to satisfy rubocop `Style/MultilineBlockChain`
- 95 specs pass, 0 rubocop offenses
- Files changed (11 files):
  - `gems/supabase-storage/lib/supabase/storage/errors.rb` (StorageError -> module, StorageBaseError, re-parented)
  - `gems/supabase-storage/lib/supabase/storage/client.rb` (handle_response raises, removed api_error_result)
  - `gems/supabase-storage/lib/supabase/storage/storage_file_api.rb` (handle_response/raise_on_error, removed helpers)
  - `gems/supabase-storage/lib/supabase/storage/bucket_api.rb` (raise instead of return hash)
  - `gems/supabase-storage/lib/supabase/storage/file_operations.rb` (return data directly, raise on error)
  - `gems/supabase-storage/lib/supabase/storage/url_operations.rb` (return data directly, raise on error)
  - `gems/supabase-storage/spec/supabase/storage/bucket_api_spec.rb`
  - `gems/supabase-storage/spec/supabase/storage/errors_spec.rb`
  - `gems/supabase-storage/spec/supabase/storage/file_operations_spec.rb`
  - `gems/supabase-storage/spec/supabase/storage/url_operations_spec.rb`
- **Learnings:**
  - `raise_error` with `.and having_attributes` compound matcher doesn't work with block expectations in RSpec
  - Use `raise_error(Class, message) { |e| expect(e.attr)... }` to check error + attributes without multiline block chain
  - The module mixin pattern from US-002 applied cleanly to the storage gem
---

## 2026-02-10 - US-004
- Converted PostgREST client from `{ data:, error: }` hash returns to Response value objects and exception raising
- Error hierarchy updated: `PostgrestError < Supabase::ApiError` (keeps details, hint, code attributes)
- Created `Supabase::PostgREST::Response` value object with `data`, `count`, `status`, `status_text` accessors
- `execute` returns `Response` on success, raises `PostgrestError` on HTTP errors
- `handle_fetch_error` always raises `PostgrestError` with code `FETCH_ERROR` (removed conditional logic)
- Removed `throw_on_error` method and `@throw_on_error` flag entirely (raising is now the only behavior)
- `handle_maybe_single` updated to work with Response objects (`.data` instead of `[:data]`), returns new Response
- `PostgrestError#initialize` uses `**options` keyword splat to satisfy rubocop `Metrics/ParameterLists` (6 params > 5 limit)
- `raise_on_error` uses modifier `unless` and multi-line hash alignment to satisfy rubocop
- All 4 spec files updated: `result[:data]` -> `result.data`, `result[:status]` -> `result.status`, error checks -> `raise_error` matchers
- Removed throw_on_error tests (EH-06, EH-07, EH-08) and BI-02 (throw_on_error returns new builder)
- 124 specs pass, 0 rubocop offenses
- Files changed (11 files):
  - `gems/supabase-postgrest/lib/supabase/postgrest.rb` (added response require)
  - `gems/supabase-postgrest/lib/supabase/postgrest/response.rb` (new: Response value object)
  - `gems/supabase-postgrest/lib/supabase/postgrest/errors.rb` (PostgrestError < Supabase::ApiError, **options)
  - `gems/supabase-postgrest/lib/supabase/postgrest/builder.rb` (removed throw_on_error)
  - `gems/supabase-postgrest/lib/supabase/postgrest/response_handler.rb` (raise_on_error, returns Response)
  - `gems/supabase-postgrest/lib/supabase/postgrest/filter_builder.rb` (handle_maybe_single with Response)
  - `gems/supabase-postgrest/lib/supabase/postgrest/client.rb` (updated docs)
  - `gems/supabase-postgrest/spec/supabase/postgrest/errors_spec.rb`
  - `gems/supabase-postgrest/spec/supabase/postgrest/crud_spec.rb`
  - `gems/supabase-postgrest/spec/supabase/postgrest/transforms_spec.rb`
  - `gems/supabase-postgrest/spec/supabase/postgrest/client_spec.rb`
- **Learnings:**
  - Use `**options` keyword splat when a constructor needs > 5 params (rubocop Metrics/ParameterLists)
  - PostgREST Response as a simple value object (attr_reader only) is cleaner than hash returns
  - Removing throw_on_error simplifies both source and tests significantly
---

## 2026-02-10 - US-005
- Converted Functions client from `{ data:, error: }` hash returns to direct data returns with exception raising
- Error hierarchy updated: `FunctionsHttpError < Supabase::ApiError`, `FunctionsRelayError < Supabase::ApiError`, `FunctionsFetchError < Supabase::NetworkError`
- `FunctionsError` converted from class to module (mixin) so `is_a?(FunctionsError)` still works
- `FunctionsBaseError < Supabase::Error` added as concrete base class
- `invoke` returns parsed response data directly on success
- `process_response` raises `FunctionsRelayError`/`FunctionsHttpError` instead of returning error hashes
- `rescue Faraday::Error, IOError` raises `FunctionsFetchError` instead of returning hash
- Invalid HTTP method raises `FunctionsFetchError` (extracted to `validate_method` to satisfy ABC size limit)
- Used `raise Class, message` style (not `raise Class.new(message)`) for rubocop `Style/RaiseArgs`
- All spec `result[:data]` -> `result`, `result[:error]` -> `raise_error` matchers
- 65 specs pass, 0 rubocop offenses
- Files changed (4 files):
  - `gems/supabase-functions/lib/supabase/functions/errors.rb` (FunctionsError -> module, re-parented classes)
  - `gems/supabase-functions/lib/supabase/functions/client.rb` (raise instead of return hash)
  - `gems/supabase-functions/lib/supabase/functions/response_handler.rb` (raise instead of return hash)
  - `gems/supabase-functions/spec/supabase/functions/client_spec.rb`
- **Learnings:**
  - `raise Class, "msg"` preferred over `raise Class.new("msg")` by rubocop Style/RaiseArgs (when no extra kwargs needed)
  - Extract validation to helper method when ABC size is borderline (17.23 > 17 limit)
---

## 2026-02-10 - US-006
- Updated main Supabase::Client integration to work with new exception-based sub-clients
- `auth_token_manager.rb`: Fixed `resolve_current_token` to use `[:session]` instead of `.dig(:data, :session)` (get_session no longer returns `{ data: { session: } }` wrapper)
- `delegation.rb`: Updated rpc yard doc to reference `Response` return type and `PostgrestError` raise
- `client_spec.rb`: Updated get_session stubs from `{ data: { session: nil }, error: nil }` to `{ session: nil }`, rpc delegation test uses Response-like double
- `errors_spec.rb`: Updated cross-gem hierarchy tests for AuthError/StorageError/FunctionsError being modules (use `.to be_a(Module)` and `BaseError.new` instead of `.new`)
- 702 total specs pass (all 6 gems), 0 rubocop offenses (119 files)
- Files changed (4 files):
  - `gems/supabase/lib/supabase/auth_token_manager.rb`
  - `gems/supabase/lib/supabase/delegation.rb`
  - `gems/supabase/spec/supabase/client_spec.rb`
  - `gems/supabase/spec/supabase/errors_spec.rb`
---

## 2026-02-10 - US-007
- Final cross-gem validation confirms all acceptance criteria are met
- Zero `result[:error]` patterns remain in any spec files
- Zero `result[:data]` patterns remain in any spec files
- Zero `{ data: nil, error: }` patterns remain in any source files
- PostgREST specs assert on Response object attributes (`.data`, `.count`, `.status`, `.status_text`)
- Error attribute assertions preserved in `raise_error { |e| }` blocks throughout
- **702 total specs pass across all 6 gems, 0 failures**
- **119 files inspected by rubocop, 0 offenses**
- No new code changes needed - US-001 through US-006 covered all tests
---

## PRD COMPLETE
All 7 user stories pass. The SDK now uses idiomatic Ruby exception raising across all gems:
- Auth: `AuthApiError`, `AuthRetryableFetchError`, `AuthUnknownError` (raise)
- Storage: `StorageApiError`, `StorageUnknownError` (raise)
- PostgREST: `PostgrestError` (raise), returns `Response` value object
- Functions: `FunctionsHttpError`, `FunctionsRelayError`, `FunctionsFetchError` (raise)
- Main client: Integration updated for new patterns
