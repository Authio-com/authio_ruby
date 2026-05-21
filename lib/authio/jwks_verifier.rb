# frozen_string_literal: true

require "json"
require "jwt"
require "net/http"
require "uri"

module Authio
  # Verifies Authio access JWTs against the cached JWKS.
  #
  # Authio's auth-core signs JWTs with EdDSA (Ed25519). JWT.decode is
  # routed through the JWKS keyset; the keyset is fetched lazily and
  # cached for ~10 minutes.
  class JwksVerifier
    CACHE_TTL = 600
    COOLDOWN = 30

    def initialize(api_url:, issuer:, audience:, http: nil)
      @api_url = api_url.to_s.sub(%r{/+\z}, "")
      @issuer = issuer
      @audience = audience
      @http = http
      @keys = nil
      @fetched_at = 0
    end

    # @return [Hash] decoded JWT claims, e.g. { "sub" => "user_...", ... }
    def verify(token)
      keys = fetch_keys
      payload, = JWT.decode(
        token,
        nil,
        true,
        algorithms: ["EdDSA"],
        iss: @issuer,
        aud: @audience,
        verify_iss: true,
        verify_aud: true,
        jwks: { keys: keys },
      )
      raise "authio: token missing sub" if payload["sub"].nil? || payload["sub"].empty?

      payload
    end

    private

    def fetch_keys
      now = Time.now.to_i
      return @keys if @keys && now - @fetched_at < CACHE_TTL
      return @keys if @keys && now - @fetched_at < COOLDOWN

      uri = URI("#{@api_url}/v1/auth/.well-known/jwks.json")
      body = @http ? @http.get(uri.to_s) : Net::HTTP.get(uri)
      data = JSON.parse(body)
      raise "authio: invalid JWKS at #{uri}" unless data["keys"].is_a?(Array)

      @keys = data["keys"]
      @fetched_at = now
      @keys
    end
  end
end
