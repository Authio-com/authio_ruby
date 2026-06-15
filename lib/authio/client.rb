# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"
require "time"
require "uri"

module Authio
  class Client
    RESERVED_CLAIMS = %w[
      iss sub aud exp iat jti nbf scope scopes sid act_org act_role
      client_id token_type project_id is_impersonation
      impersonator_user_id impersonator_email imp_grant_id
    ].freeze

    def self.default
      @default ||= new(Authio.configuration)
    end

    def self.reset_default!
      @default = nil
    end

    attr_reader :configuration

    def initialize(configuration = Authio.configuration)
      @configuration = configuration
      @verifier = JwksVerifier.new(
        api_url: configuration.effective_api_url,
        issuer: configuration.effective_issuer,
        audience: configuration.audience,
      )
    end

    # Verify an Authio access token. Returns a {Session} or nil when the
    # token is missing / expired / cryptographically invalid.
    def verify_token(token)
      return nil if token.nil? || token.empty?

      begin
        claims = @verifier.verify(token)
      rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature, StandardError
        return nil
      end

      merged = claims.reject { |k, _| RESERVED_CLAIMS.include?(k) }
      Session.new(
        session_id: claims["sid"].to_s,
        user_id: claims["sub"].to_s,
        org_id: (claims["act_org"] && !claims["act_org"].empty? ? claims["act_org"] : nil),
        role: (claims["act_role"] && !claims["act_role"].empty? ? claims["act_role"] : nil),
        expires_at: claims["exp"] ? Time.at(claims["exp"]).utc.iso8601 : Time.now.utc.iso8601,
        claims: merged,
        impersonation?: claims["is_impersonation"] == true,
        impersonator_email: claims["impersonator_email"],
      )
    end

    # Build the hosted sign-in URL the browser should send the user to.
    # The hosted UI handles passkey / magic-link / OAuth and redirects
    # back to `redirect_url` with `?access_token=…` on success.
    def sign_in_url(redirect_url:)
      base = configuration.effective_api_url
      "#{base}/v1/auth/sign-in?publishable_key=#{CGI.escape(configuration.publishable_key)}&redirect_url=#{CGI.escape(redirect_url)}"
    end

    # Server-side magic-link starter — useful for testing.
    def start_magic_link(email:, redirect_url:)
      uri = URI("#{configuration.effective_api_url}/v1/auth/magic-link/start")
      req = Net::HTTP::Post.new(uri, {
        "content-type" => "application/json",
        "x-publishable-key" => configuration.publishable_key,
      })
      req.body = JSON.generate({ email: email, redirect_url: redirect_url })
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      res = http.request(req)
      raise Authio::Error.new(code: "magic_link_failed", message: res.body.to_s, status: res.code.to_i) unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body) rescue {}
    end
  end
end
