# Supabase Auth (Ruby)

Ruby client for [Supabase Auth](https://supabase.com/docs/guides/auth) (GoTrue). Supports email/password, OAuth, OTP, SSO, anonymous sign-in, MFA, admin operations, PKCE flow, and automatic token refresh.

## Installation

```ruby
gem "supabase-auth"
```

## Usage

```ruby
require "supabase/auth"

client = Supabase::Auth::Client.new(
  url: "https://your-project.supabase.co/auth/v1",
  headers: { "apikey" => "your-key", "Authorization" => "Bearer your-key" }
)

result = client.sign_in_with_password(email: "user@example.com", password: "secret")
session = result[:data][:session]
```

## API Reference

### `Supabase::Auth::Client`

#### `initialize(url:, headers: {}, **options)`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `url` | String | _(required)_ | Auth service URL |
| `headers` | Hash | `{}` | Default headers |
| `storage_key` | String | `"supabase.auth.token"` | Session storage key |
| `auto_refresh_token` | Boolean | `true` | Auto-refresh expired tokens |
| `persist_session` | Boolean | `true` | Persist session to storage |
| `detect_session_in_url` | Boolean | `true` | Detect session from URL |
| `flow_type` | Symbol | `:implicit` | Auth flow (`:implicit` or `:pkce`) |
| `storage` | StorageAdapter | `MemoryStorage.new` | Custom session storage |
| `lock` | Lock | `nil` | Custom lock for thread safety |
| `fetch` | Proc | `nil` | Custom Faraday connection factory |
| `debug` | Boolean | `false` | Enable debug logging |

### Sign Up

#### `sign_up(password:, **options) -> Hash`

Signs up a new user with email or phone.

| Option | Type | Description |
|--------|------|-------------|
| `email` | String | User email (required if no phone) |
| `phone` | String | User phone (required if no email) |
| `password` | String | Password (required) |
| `data` | Hash | Custom user metadata |
| `captcha_token` | String | Captcha verification token |
| `channel` | String | SMS channel (default `"sms"`) |

```ruby
# Email sign up
client.sign_up(email: "user@example.com", password: "secure-password")

# Phone sign up
client.sign_up(phone: "+1234567890", password: "secure-password")

# With metadata
client.sign_up(email: "user@example.com", password: "pwd", data: { name: "Jane" })
```

Returns `{ data: { user:, session: }, error: nil }`. Session is `nil` if email confirmation is required.

#### `sign_in_anonymously(**options) -> Hash`

Creates an anonymous user.

```ruby
result = client.sign_in_anonymously
user = result[:data][:user]  # user[:is_anonymous] == true
```

### Sign In

#### `sign_in_with_password(password:, **options) -> Hash`

```ruby
client.sign_in_with_password(email: "user@example.com", password: "secret")
client.sign_in_with_password(phone: "+1234567890", password: "secret")
```

#### `sign_in_with_oauth(**options) -> Hash`

Builds an OAuth authorize URL (no HTTP call). Redirect the user to the returned URL.

| Option | Type | Description |
|--------|------|-------------|
| `provider` | String | OAuth provider (`"github"`, `"google"`, etc.) |
| `redirect_to` | String | Post-login redirect URL |
| `scopes` | String | OAuth scopes |
| `skip_browser_redirect` | Boolean | Skip browser redirect |
| `query_params` | Hash | Additional query parameters |

```ruby
result = client.sign_in_with_oauth(provider: "github", redirect_to: "https://myapp.com/callback")
redirect_url = result[:data][:url]
```

#### `sign_in_with_otp(**options) -> Hash`

Sends a one-time password via email or phone.

```ruby
client.sign_in_with_otp(email: "user@example.com")
client.sign_in_with_otp(phone: "+1234567890", channel: "sms")
```

#### `sign_in_with_id_token(**options) -> Hash`

Signs in using an ID token from an external provider.

```ruby
client.sign_in_with_id_token(provider: "google", token: "eyJ...")
```

#### `sign_in_with_sso(**options) -> Hash`

Signs in via SSO. Returns a URL to redirect the user to.

```ruby
client.sign_in_with_sso(domain: "company.com")
client.sign_in_with_sso(provider_id: "sso-provider-uuid")
```

#### `verify_otp(**options) -> Hash`

Verifies an OTP token.

```ruby
client.verify_otp(email: "user@example.com", token: "123456", type: "email")
client.verify_otp(phone: "+1234567890", token: "123456", type: "sms")
```

#### `exchange_code_for_session(auth_code) -> Hash`

Exchanges a PKCE authorization code for a session.

```ruby
result = client.exchange_code_for_session("auth-code-from-callback")
```

### Session Management

#### `get_session -> Hash`

Returns the current session, refreshing if expired.

```ruby
result = client.get_session
session = result[:data][:session]  # nil if not authenticated
```

#### `set_session(access_token:, refresh_token:) -> Hash`

Manually sets a session from existing tokens.

```ruby
client.set_session(access_token: "eyJ...", refresh_token: "refresh-token")
```

#### `refresh_session(current_session: nil) -> Hash`

Forces a token refresh.

```ruby
client.refresh_session
```

#### `sign_out(scope: :global) -> Hash`

Signs out the user. Scopes: `:global` (all sessions), `:local` (current only), `:others` (other sessions).

```ruby
client.sign_out                    # global sign out
client.sign_out(scope: :local)     # local only
```

#### `start_auto_refresh` / `stop_auto_refresh`

Manually control the automatic token refresh background thread.

### User Management

#### `get_user(jwt: nil) -> Hash`

Gets the current user (always makes an HTTP call).

```ruby
user = client.get_user[:data][:user]
```

#### `update_user(**options) -> Hash`

Updates the current user's profile.

```ruby
client.update_user(data: { display_name: "Jane Doe" })
client.update_user(email: "new@example.com")
client.update_user(password: "new-password")
```

#### `reset_password_for_email(email, redirect_to: nil, captcha_token: nil) -> Hash`

Sends a password recovery email.

#### `reauthenticate -> Hash`

Requests reauthentication for the current session.

#### `resend(type:, email: nil, phone: nil) -> Hash`

Resends a confirmation or OTP.

### Auth State Events

#### `on_auth_state_change { |event, session| } -> Subscription`

Registers a listener for auth state changes.

**Events:** `:initial_session`, `:signed_in`, `:signed_out`, `:token_refreshed`, `:user_updated`, `:password_recovery`, `:mfa_challenge_verified`

```ruby
subscription = client.on_auth_state_change do |event, session|
  case event
  when :signed_in
    puts "User signed in"
  when :signed_out
    puts "User signed out"
  when :token_refreshed
    puts "Token refreshed"
  end
end

# Unsubscribe
subscription.unsubscribe
```

### MFA (Multi-Factor Authentication)

Access via `client.mfa`.

#### `mfa.enroll(factor_type:, friendly_name: nil, issuer: nil, phone: nil) -> Hash`

Enrolls a new MFA factor.

```ruby
# TOTP
result = client.mfa.enroll(factor_type: "totp", friendly_name: "My Authenticator")
qr_code = result[:data][:totp][:qr_code]

# Phone
result = client.mfa.enroll(factor_type: "phone", phone: "+1234567890")
```

#### `mfa.challenge(factor_id:) -> Hash`

Creates an MFA challenge.

#### `mfa.verify(factor_id:, challenge_id:, code:) -> Hash`

Verifies an MFA challenge.

#### `mfa.challenge_and_verify(factor_id:, code:) -> Hash`

Convenience method combining challenge + verify.

#### `mfa.unenroll(factor_id:) -> Hash`

Removes an MFA factor.

#### `mfa.list_factors -> Hash`

Lists enrolled factors grouped by type.

```ruby
result = client.mfa.list_factors
totp_factors = result[:data][:totp]
phone_factors = result[:data][:phone]
```

#### `mfa.get_authenticator_assurance_level -> Hash`

Returns the current and next assurance levels.

```ruby
result = client.mfa.get_authenticator_assurance_level
# => { data: { current_level: "aal1", next_level: "aal2", current_authentication_methods: [...] } }
```

### Admin API

Access via `client.admin`. Requires a service role key.

#### `admin.create_user(**options) -> Hash`

```ruby
client.admin.create_user(
  email: "new@example.com",
  password: "temp-password",
  email_confirm: true
)
```

#### `admin.list_users(page: nil, per_page: nil) -> Hash`

#### `admin.get_user_by_id(uid) -> Hash`

#### `admin.update_user_by_id(uid, **attributes) -> Hash`

#### `admin.delete_user(id, should_soft_delete: false) -> Hash`

#### `admin.invite_user_by_email(email, data: nil, redirect_to: nil) -> Hash`

#### `admin.generate_link(type:, email:, **options) -> Hash`

Generates auth links (signup, magiclink, recovery, invite, email_change).

```ruby
result = client.admin.generate_link(type: "magiclink", email: "user@example.com")
link = result[:data][:properties][:action_link]
```

#### `admin.sign_out(jwt, scope: :global) -> Hash`

Signs out a user using their JWT.

### PKCE Flow

Enable PKCE by passing `flow_type: :pkce` in the constructor. PKCE parameters are automatically included in sign-up, OTP, OAuth, SSO, and password recovery methods.

```ruby
client = Supabase::Auth::Client.new(
  url: "https://your-project.supabase.co/auth/v1",
  headers: { "apikey" => "your-key" },
  flow_type: :pkce
)

# OAuth with PKCE
result = client.sign_in_with_oauth(provider: "github")
# After callback with auth code:
client.exchange_code_for_session("auth-code")
```

## Error Hierarchy

| Error Class | When |
|------------|------|
| `AuthError` | Base class |
| `AuthApiError` | 4xx HTTP response with JSON body |
| `AuthUnknownError` | 4xx HTTP response without JSON body |
| `AuthRetryableFetchError` | 502/503/504 or network failures |
| `AuthSessionMissingError` | No session found when expected |
| `AuthWeakPasswordError` | Password does not meet requirements |
| `AuthInvalidCredentialsError` | Invalid credentials |
| `AuthInvalidTokenResponseError` | Invalid token response format |
| `AuthPKCEGrantCodeExchangeError` | PKCE code exchange failure |

## Storage Adapter

Implement a custom storage adapter for session persistence:

```ruby
class RedisStorage
  def initialize(redis)
    @redis = redis
  end

  def get_item(key)
    @redis.get(key)
  end

  def set_item(key, value)
    @redis.set(key, value)
  end

  def remove_item(key)
    @redis.del(key)
  end
end

client = Supabase::Auth::Client.new(
  url: "...",
  headers: {},
  storage: RedisStorage.new(Redis.new)
)
```
