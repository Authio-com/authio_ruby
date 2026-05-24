<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/logo-dark.png">
    <img alt="Authio" src=".github/logo-light.png" width="220">
  </picture>
</p>

# authio (Ruby gem)

> Part of **[Authio Lobby](https://authio.com/products/lobby)** —
> Authio's drop-in passwordless authentication. Learn more at
> https://authio.com/products/lobby.

Authio Ruby SDK. Verifies session JWTs against Authio's JWKS, builds hosted
sign-in URLs, and slots into Rails controllers via a `before_action` helper.

## What's new — 2026-05-23 WorkOS-parity sprint

The Authio API gained four new product surfaces this sprint
([`authio_proto`](https://github.com/authio-com/authio_proto)). The Ruby gem already verifies the new JWT
shape end-to-end (`claims["roles"]` and `claims["permissions"]` ride
along on every customer session); idiomatic helpers for the new
write-side endpoints are queued for the next release. Reference docs:

- Embeddable widgets — [docs.authio.com/widgets/overview](https://docs.authio.com/widgets/overview)
- Synchronous Actions — [docs.authio.com/actions/overview](https://docs.authio.com/actions/overview)
  (Sinatra signature verification snippet on
  [docs.authio.com/actions/signature-verification](https://docs.authio.com/actions/signature-verification))
- DCR / CIMD / MCP — [docs.authio.com/concepts/dynamic-client-registration](https://docs.authio.com/concepts/dynamic-client-registration)
- Roles + permissions — [docs.authio.com/concepts/roles-and-permissions](https://docs.authio.com/concepts/roles-and-permissions)

## Install

```ruby
# Gemfile
gem "authio", "~> 0.1"
```

```bash
bundle install
```

## Configure

```ruby
# config/initializers/authio.rb
Authio.configure do |config|
  config.api_key = ENV.fetch("AUTHIO_SECRET_KEY", "")
  config.api_url = ENV.fetch("AUTHIO_API_URL", "https://api.authio.com")
  config.publishable_key = ENV.fetch("AUTHIO_PUBLISHABLE_KEY", "")
end
```

## Use in a Rails controller

```ruby
class ApplicationController < ActionController::Base
  private

  def authenticate_authio!
    token = cookies[:authio_session]
    @authio_session = token.present? ? Authio::Client.default.verify_token(token) : nil
    unless @authio_session
      redirect_to "/auth/sign-in?redirect_url=#{CGI.escape(request.fullpath)}"
    end
  end
  helper_method :authio_session
  attr_reader :authio_session
end

class DashboardController < ApplicationController
  before_action :authenticate_authio!

  def index
    # @authio_session.user_id, @authio_session.org_id, @authio_session.role
  end
end
```

## API

| Method                                            | Description                                       |
| ------------------------------------------------- | ------------------------------------------------- |
| `Authio.configure { |c| ... }`                    | Set api_key / api_url / publishable_key.          |
| `Authio::Client.default`                          | Shared singleton.                                 |
| `client.verify_token(token)`                      | Verify JWT vs cached JWKS. Returns `Session` or `nil`. |
| `client.sign_in_url(redirect_url: "...")`         | Build the hosted-UI redirect URL.                 |
| `client.start_magic_link(email:, redirect_url:)`  | POST `/v1/auth/magic-link/start`. Useful for tests. |

`Authio::Session` exposes `session_id`, `user_id`, `org_id`, `role`,
`expires_at`, `claims`, `impersonation?`, `impersonator_email`.

## Requirements

- Ruby 3.0+
- `jwt` ~> 2.7 (installed automatically)

## License

MIT
