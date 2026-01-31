# OmniAuth QuickBooks OAuth2 Modern

An OmniAuth strategy for authenticating with [QuickBooks Online](https://quickbooks.intuit.com/) using OAuth 2.0.

**Compatible with OmniAuth 2.0+** - This gem is designed for modern Rails applications using OmniAuth 2.0 or later.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'omniauth-quickbooks-oauth2-modern'
```

Then execute:

```shell
$ bundle install
```

Or install it yourself:

```shell
$ gem install omniauth-quickbooks-oauth2-modern
```

## QuickBooks Developer Setup

1. Go to the [Intuit Developer Portal](https://developer.intuit.com/)
2. Create a new app or select an existing one
3. Note your **Client ID** and **Client Secret**
4. Configure your **Redirect URIs** (e.g., `https://yourapp.com/auth/quickbooks_oauth2_modern/callback`)

For more details, read the [QuickBooks OAuth 2.0 documentation](https://developer.intuit.com/app/developer/qbo/docs/develop/authentication-and-authorization/oauth-2.0).

## Usage

### Standalone OmniAuth

Add the middleware to your application in `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :quickbooks_oauth2_modern,
           ENV['QBO_CLIENT_ID'],
           ENV['QBO_CLIENT_SECRET'],
           sandbox: Rails.env.development?,
           scope: 'com.intuit.quickbooks.accounting openid profile email'
end

# Required for OmniAuth 2.0+
OmniAuth.config.allowed_request_methods = %i[get post]
```

You can now access the OmniAuth QuickBooks URL at `/auth/quickbooks_oauth2_modern`.

### With Devise

Add the provider to your Devise configuration in `config/initializers/devise.rb`:

```ruby
config.omniauth :quickbooks_oauth2_modern,
                ENV['QBO_CLIENT_ID'],
                ENV['QBO_CLIENT_SECRET'],
                sandbox: !Rails.env.production?,
                scope: 'com.intuit.quickbooks.accounting openid profile email'
```

**Do not** create a separate `config/initializers/omniauth.rb` file when using Devise.

Add to your routes in `config/routes.rb`:

```ruby
devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
```

Make your User model omniauthable in `app/models/user.rb`:

```ruby
devise :omniauthable, omniauth_providers: [:quickbooks_oauth2_modern]
```

Create the callbacks controller at `app/controllers/users/omniauth_callbacks_controller.rb`:

```ruby
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def quickbooks_oauth2_modern
    @user = User.from_omniauth(request.env['omniauth.auth'])

    if @user.persisted?
      flash[:notice] = I18n.t('devise.omniauth_callbacks.success', kind: 'QuickBooks')
      sign_in_and_redirect @user, event: :authentication
    else
      session['devise.quickbooks_data'] = request.env['omniauth.auth'].except('extra')
      redirect_to new_user_registration_url, alert: @user.errors.full_messages.join("\n")
    end
  end

  def failure
    redirect_to root_path, alert: "Authentication failed: #{failure_message}"
  end
end
```

For your views, create a login button:

```erb
<%= button_to "Sign in with QuickBooks", user_quickbooks_oauth2_modern_omniauth_authorize_path, method: :post %>
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `sandbox` | `true` | Use sandbox environment. Set to `false` for production. |
| `scope` | `com.intuit.quickbooks.accounting openid profile email` | OAuth scopes to request. |
| `redirect_uri` | Auto-generated | Custom redirect URI (optional). |

### Example with all options:

```ruby
provider :quickbooks_oauth2_modern,
         ENV['QBO_CLIENT_ID'],
         ENV['QBO_CLIENT_SECRET'],
         sandbox: false,
         scope: 'com.intuit.quickbooks.accounting openid profile email',
         redirect_uri: 'https://myapp.com/auth/quickbooks_oauth2_modern/callback'
```

## Auth Hash

Here's an example of the authentication hash available in the callback via `request.env['omniauth.auth']`:

```ruby
{
  "provider" => "quickbooks_oauth2_modern",
  "uid" => "1234567890",  # realmId (company ID)
  "info" => {
    "email" => "user@example.com",
    "first_name" => "John",
    "last_name" => "Doe",
    "name" => "John Doe",
    "phone" => "555-123-4567",
    "realm_id" => "1234567890"
  },
  "credentials" => {
    "token" => "ACCESS_TOKEN",
    "refresh_token" => "REFRESH_TOKEN",
    "expires_at" => 1704067200,
    "expires" => true
  },
  "extra" => {
    "realm_id" => "1234567890",
    "raw_info" => {
      "sub" => "user-uuid",
      "email" => "user@example.com",
      "emailVerified" => true,
      "givenName" => "John",
      "familyName" => "Doe",
      "phoneNumber" => "555-123-4567"
    }
  }
}
```

## Sandbox vs Production

QuickBooks uses different URLs for sandbox and production environments:

| Environment | Userinfo URL |
|-------------|--------------|
| Sandbox | `https://sandbox-accounts.platform.intuit.com` |
| Production | `https://accounts.platform.intuit.com` |

The gem automatically handles this based on the `sandbox` option.

**Important:** You need separate QuickBooks apps for sandbox and production. Make sure to use the correct credentials for each environment.

## Token Management

QuickBooks access tokens expire after **1 hour**. Refresh tokens are valid for **100 days** with a rolling expiry.

Store tokens securely and implement refresh logic:

```ruby
def self.from_omniauth(auth)
  user = where(provider: auth.provider, uid: auth.uid).first_or_create do |u|
    u.email = auth.info.email
    u.password = Devise.friendly_token[0, 20]
  end

  # Update tokens on each login
  user.update(
    qbo_access_token: auth.credentials.token,
    qbo_refresh_token: auth.credentials.refresh_token,
    qbo_token_expires_at: Time.at(auth.credentials.expires_at),
    qbo_realm_id: auth.info.realm_id
  )

  user
end
```

## Token Refresh

This gem includes a `TokenClient` class to easily refresh tokens in your Rails app.

### Basic Usage

```ruby
# Create a client instance
client = OmniAuth::QuickbooksOauth2Modern::TokenClient.new(
  client_id: ENV['QBO_CLIENT_ID'],
  client_secret: ENV['QBO_CLIENT_SECRET']
)

# Refresh an expired token
result = client.refresh_token(account.qbo_refresh_token)

if result.success?
  account.update!(
    qbo_access_token: result.access_token,
    qbo_refresh_token: result.refresh_token,
    qbo_token_expires_at: Time.at(result.expires_at)
  )
else
  Rails.logger.error "Token refresh failed: #{result.error}"
end
```

### Check Token Expiration

```ruby
# Check if token is expired (with 5-minute buffer by default)
client.token_expired?(account.qbo_token_expires_at)

# Custom buffer (e.g., refresh 1 hour before expiry)
client.token_expired?(account.qbo_token_expires_at, buffer_seconds: 3600)
```

### Rails Service Example

```ruby
# app/services/quickbooks_api_service.rb
class QuickBooksApiService
  def initialize(account)
    @account = account
    @client = OmniAuth::QuickbooksOauth2Modern::TokenClient.new(
      client_id: ENV['QBO_CLIENT_ID'],
      client_secret: ENV['QBO_CLIENT_SECRET']
    )
  end

  def with_valid_token
    refresh_if_expired!
    yield @account.qbo_access_token
  end

  private

  def refresh_if_expired!
    return unless @client.token_expired?(@account.qbo_token_expires_at)

    result = @client.refresh_token(@account.qbo_refresh_token)
    raise "Token refresh failed: #{result.error}" unless result.success?

    @account.update!(
      qbo_access_token: result.access_token,
      qbo_refresh_token: result.refresh_token,
      qbo_token_expires_at: Time.at(result.expires_at)
    )
  end
end

# Usage
QuickBooksApiService.new(current_account).with_valid_token do |token|
  # Make API calls with valid token
  response = Faraday.get("https://quickbooks.api.intuit.com/v3/company/#{realm_id}/query") do |req|
    req.headers['Authorization'] = "Bearer #{token}"
    req.params['query'] = "SELECT * FROM Customer"
  end
end
```

### TokenResult Object

The `refresh_token` method returns a `TokenResult` object with:

| Method | Description |
|--------|-------------|
| `success?` | Returns `true` if refresh succeeded |
| `failure?` | Returns `true` if refresh failed |
| `access_token` | The new access token |
| `refresh_token` | The new refresh token |
| `expires_at` | Unix timestamp when token expires |
| `expires_in` | Seconds until token expires |
| `error` | Error message if failed |
| `raw_response` | Full response hash from Intuit |

## Scopes

Common QuickBooks scopes:

| Scope | Description |
|-------|-------------|
| `com.intuit.quickbooks.accounting` | Access to QuickBooks Online Accounting API |
| `com.intuit.quickbooks.payment` | Access to QuickBooks Payments API |
| `openid` | OpenID Connect (required for userinfo) |
| `profile` | User profile information |
| `email` | User email address |
| `phone` | User phone number |
| `address` | User address |

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/dan1d/omniauth-quickbooks-oauth2-modern](https://github.com/dan1d/omniauth-quickbooks-oauth2-modern).

1. Fork it
2. Create your feature branch (`git checkout -b feature/my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-new-feature`)
5. Create a new Pull Request

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rspec` to run the tests.

```shell
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
