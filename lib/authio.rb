# frozen_string_literal: true

require_relative "authio/version"
require_relative "authio/configuration"
require_relative "authio/session"
require_relative "authio/jwks_verifier"
require_relative "authio/client"
require_relative "authio/passkeys"
require_relative "authio/errors"

# Authio — passwordless, multi-org auth for B2B Ruby / Rails apps.
#
#   Authio.configure do |c|
#     c.api_key = ENV["AUTHIO_SECRET_KEY"]
#     c.api_url = "https://api.authio.com"
#     c.publishable_key = ENV["AUTHIO_PUBLISHABLE_KEY"]
#   end
#
#   session = Authio::Client.default.verify_token(token)
#   session&.user_id  # => "user_..."
#   session&.org_id   # => "org_..." or nil for users who haven't picked an org yet
module Authio
  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset_configuration!
    @configuration = Configuration.new
  end
end
