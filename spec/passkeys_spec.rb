# frozen_string_literal: true

require "webmock"
include WebMock::API

require "authio"

RSpec.describe Authio::Passkeys do
  let(:api_url) { "https://auth-api.test" }
  let(:project_id) { "proj_test" }
  let(:access_token) { "sess_tok" }

  before do
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  after do
    WebMock.reset!
    WebMock.allow_net_connect!
  end

  describe ".build_enroll_passkey_url" do
    it "threads add_credential params for hosted UI" do
      url = described_class.build_enroll_passkey_url(
        sign_in_url: "https://auth.acme.com",
        project_id: "proj_abc",
        email: "user@acme.com",
        register_token: "intent.jwt",
        return_url: "https://app.acme.com/settings/security",
        next: "/settings/security",
      )

      uri = URI(url)
      expect(uri.origin).to eq("https://auth.acme.com")
      params = URI.decode_www_form(uri.query).to_h
      expect(params).to include(
        "mode" => "add_credential",
        "project_id" => "proj_abc",
        "email" => "user@acme.com",
        "token" => "intent.jwt",
        "redirect_uri" => "https://app.acme.com/settings/security",
        "next" => "/settings/security",
      )
    end

    it "strips a trailing slash from sign_in_url" do
      url = described_class.build_enroll_passkey_url(
        sign_in_url: "https://lobby.authio.com/",
        project_id: project_id,
        email: "user@acme.com",
        register_token: "intent.jwt",
        return_url: "https://app.acme.com/account",
      )

      expect(url).to start_with("https://lobby.authio.com?")
    end
  end

  describe ".list_passkeys" do
    it "lists passkeys with bearer auth" do
      stub_request(:get, "#{api_url}/v1/me/passkeys")
        .with(
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "X-Authio-Project" => project_id,
          },
        )
        .to_return(
          status: 200,
          body: {
            data: [
              {
                id: "cred_1",
                nickname: "MacBook",
                aaguid: nil,
                authenticator_name: "Touch ID",
                transports: ["internal"],
                sign_count: 1,
                last_used_at: nil,
                created_at: "2026-01-01T00:00:00Z",
              },
            ],
          }.to_json,
          headers: { "Content-Type" => "application/json" },
        )

      rows = described_class.list_passkeys(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
      )

      expect(rows.length).to eq(1)
      expect(rows.first.nickname).to eq("MacBook")
      expect(rows.first.id).to eq("cred_1")
    end
  end

  describe ".mint_passkey_register_intent" do
    it "returns token envelope" do
      stub_request(:post, "#{api_url}/v1/me/passkeys/register-intent")
        .with(
          headers: {
            "Authorization" => "Bearer #{access_token}",
            "X-Authio-Project" => project_id,
          },
          body: "{}",
        )
        .to_return(
          status: 200,
          body: { token: "intent.jwt", expires_in: 600 }.to_json,
          headers: { "Content-Type" => "application/json" },
        )

      intent = described_class.mint_passkey_register_intent(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
      )

      expect(intent.token).to eq("intent.jwt")
      expect(intent.expires_in).to eq(600)
    end
  end

  describe ".enroll_passkey_url" do
    it "mints register intent then builds redirect URL" do
      stub_request(:post, "#{api_url}/v1/me/passkeys/register-intent")
        .to_return(
          status: 200,
          body: { token: "intent.jwt", expires_in: 600 }.to_json,
          headers: { "Content-Type" => "application/json" },
        )

      url = described_class.enroll_passkey_url(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
        sign_in_url: "https://auth.acme.com",
        email: "user@acme.com",
        return_url: "https://app.acme.com/settings",
      )

      uri = URI(url)
      params = URI.decode_www_form(uri.query).to_h
      expect(params["mode"]).to eq("add_credential")
      expect(params["token"]).to eq("intent.jwt")
      expect(params["redirect_uri"]).to eq("https://app.acme.com/settings")
    end
  end

  describe ".rename_passkey" do
    it "PATCHes nickname" do
      stub_request(:patch, "#{api_url}/v1/me/passkeys/cred_1")
        .with(body: { nickname: "Work laptop" }.to_json)
        .to_return(status: 200, body: { ok: true }.to_json)

      described_class.rename_passkey(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
        credential_id: "cred_1",
        name: "Work laptop",
      )
    end
  end

  describe ".revoke_passkey" do
    it "DELETEs credential" do
      stub_request(:delete, "#{api_url}/v1/me/passkeys/cred_1")
        .to_return(status: 200, body: { ok: true }.to_json)

      described_class.revoke_passkey(
        access_token: access_token,
        project_id: project_id,
        api_url: api_url,
        credential_id: "cred_1",
      )
    end
  end
end
