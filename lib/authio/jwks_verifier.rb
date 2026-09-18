# frozen_string_literal: true

require "json"
require "jwt"
require "jwt/eddsa"
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

    def initialize(api_url:, issuer:, audience:, project_id: nil, http: nil)
      @api_url = self.class.strip_trailing_slashes(api_url)
      @issuer = issuer
      @audience = audience
      @project_id = project_id
      @http = http
      @keys = nil
      @fetched_at = 0
    end


    # Strip trailing slashes without a regex.
    #
    # `sub(%r{/+\z}, "")` backtracks polynomially on a string of many
    # slashes (CodeQL rb/polynomial-redos). api_url is operator-configured
    # rather than attacker-supplied, so the exposure is small, but a
    # linear scan is just as short and cannot degrade.
    def self.strip_trailing_slashes(value)
      s = value.to_s
      s = s[0..-2] while s.end_with?("/")
      s
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

      assert_tenant(payload)
      payload
    end

    private

    # Tenant binding (security audit 2026-09-18).
    #
    # Signature, issuer and audience prove a token came from Authio. They
    # do NOT prove it was minted for THIS customer: auth-core signs every
    # tenant with one platform key under one fixed issuer/audience, so
    # project_id is the only claim that tells two tenants apart. Sign-up
    # is self-serve, so anyone can create ceo@your-company.com in their
    # own project and present the resulting token here.
    #
    # Unset project_id keeps the previous behaviour and warns once, so
    # upgrading the gem cannot sign anyone out on its own.
    def assert_tenant(payload)
      if @project_id.nil? || @project_id.empty?
        warn_once(
          :no_project,
          "authio: no project_id configured, so tokens are not checked against " \
          "your tenant. Any Authio-issued token will verify here, including one " \
          "minted in someone else's project. Set AUTHIO_PROJECT_ID or " \
          "Authio.configuration.project_id.",
        )
        return
      end

      claimed = payload["project_id"]
      return if claimed == @project_id

      raise "authio: token was issued for project #{claimed.inspect}, not #{@project_id.inspect}"
    end

    def warn_once(key, message)
      @warned ||= {}
      return if @warned[key]

      @warned[key] = true
      warn(message)
    end

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
