# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"
require "uri"

module Authio
  # Passkey management against auth-core `/v1/me/passkeys`.
  #
  # WebAuthn ceremonies are not available server-side — use
  # {#enroll_passkey_url} to redirect the browser to the hosted sign-in UI
  # (`mode=add_credential`).
  module Passkeys
    Passkey = Struct.new(
      :id,
      :nickname,
      :aaguid,
      :authenticator_name,
      :transports,
      :sign_count,
      :last_used_at,
      :created_at,
      keyword_init: true,
    ) do
      def self.from_hash(row)
        new(
          id: row["id"],
          nickname: row["nickname"],
          aaguid: row["aaguid"],
          authenticator_name: row["authenticator_name"],
          transports: row["transports"] || [],
          sign_count: row["sign_count"],
          last_used_at: row["last_used_at"],
          created_at: row["created_at"],
        )
      end
    end

    RegisterIntent = Struct.new(:token, :expires_in, keyword_init: true)

    module_function

    # List passkeys for the signed-in user (`GET /v1/me/passkeys`).
    def list_passkeys(access_token:, project_id:, api_url:)
      res = api_request(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
        method: "GET",
        path: "/v1/me/passkeys",
      )
      (res["data"] || []).map { |row| Passkey.from_hash(row) }
    end

    # Rename a passkey (`PATCH /v1/me/passkeys/{credential_id}`).
    def rename_passkey(access_token:, project_id:, api_url:, credential_id:, name:)
      api_request(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
        method: "PATCH",
        path: "/v1/me/passkeys/#{URI.encode_www_form_component(credential_id.to_s)}",
        body: { nickname: name },
      )
      nil
    end

    # Revoke a passkey (`DELETE /v1/me/passkeys/{credential_id}`).
    def revoke_passkey(access_token:, project_id:, api_url:, credential_id:)
      api_request(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
        method: "DELETE",
        path: "/v1/me/passkeys/#{URI.encode_www_form_component(credential_id.to_s)}",
      )
      nil
    end

    # Mint a short-lived JWT for add-credential WebAuthn (`POST register-intent`).
    def mint_passkey_register_intent(access_token:, project_id:, api_url:)
      body = api_request(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
        method: "POST",
        path: "/v1/me/passkeys/register-intent",
        body: {},
      )
      RegisterIntent.new(token: body["token"], expires_in: body["expires_in"])
    end

    # Build the hosted-UI URL for `mode=add_credential` passkey enrollment.
    def build_enroll_passkey_url(sign_in_url:, project_id:, email:, register_token:, return_url:, next: nil)
      next_path = binding.local_variable_get(:next)
      base = sign_in_url.to_s.sub(%r{/+\z}, "")
      params = [
        ["mode", "add_credential"],
        ["project_id", project_id],
        ["email", email],
        ["token", register_token],
        ["redirect_uri", return_url],
      ]
      params << ["next", next_path] unless next_path.nil?
      query = params.map { |k, v| "#{URI.encode_www_form_component(k)}=#{URI.encode_www_form_component(v.to_s)}" }.join("&")
      "#{base}?#{query}"
    end

    # Mint a register-intent token and return the hosted-UI enrollment URL.
    #
    # Redirect the browser to this URL — Ruby cannot run WebAuthn ceremonies.
    def enroll_passkey_url(access_token:, project_id:, api_url:, sign_in_url:, email:, return_url:, next: nil)
      next_path = binding.local_variable_get(:next)
      intent = mint_passkey_register_intent(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
      )
      build_enroll_passkey_url(
        sign_in_url: sign_in_url,
        project_id: project_id,
        email: email,
        register_token: intent.token,
        return_url: return_url,
        next: next_path,
      )
    end

    def api_request(access_token:, project_id:, api_url:, method:, path:, body: nil)
      base = api_url.to_s.sub(%r{/+\z}, "")
      uri = URI("#{base}#{path}")
      req_class = Net::HTTP.const_get(method.capitalize)
      req = req_class.new(uri)
      req["accept"] = "application/json"
      req["content-type"] = "application/json"
      req["authorization"] = "Bearer #{access_token}"
      req["x-authio-project"] = project_id
      req["x-authio-sdk"] = "authio-ruby/#{Authio::VERSION}"
      req.body = JSON.generate(body) if body

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      res = http.request(req)

      unless res.is_a?(Net::HTTPSuccess)
        parsed = JSON.parse(res.body) rescue {}
        raise Authio::Error.new(
          code: parsed["code"] || parsed["error"] || "request_failed",
          message: parsed["message"] || res.body.to_s,
          status: res.code.to_i,
        )
      end

      return {} if res.body.nil? || res.body.empty?

      JSON.parse(res.body)
    end
    private_class_method :api_request
  end
end
