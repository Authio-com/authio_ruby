# frozen_string_literal: true

require "base64"
require "jwt/eddsa"
require "securerandom"
require "webmock/rspec"

RSpec.describe Authio::JwksVerifier do
  let(:issuer) { "https://identity.authio.com" }
  let(:audience) { "authio" }
  let(:api_url) { "https://identity.authio.com" }
  let(:signing_key) { Ed25519::SigningKey.new(SecureRandom.random_bytes(32)) }
  let(:kid) { "test-eddsa-kid" }
  let(:jwks) do
    {
      "keys" => [
        {
          "alg" => "EdDSA",
          "crv" => "Ed25519",
          "kid" => kid,
          "kty" => "OKP",
          "use" => "sig",
          "x" => Base64.urlsafe_encode64(signing_key.verify_key.to_bytes, padding: false),
        },
      ],
    }
  end

  before do
    stub_request(:get, "#{api_url}/v1/auth/.well-known/jwks.json")
      .to_return(status: 200, body: jwks.to_json, headers: {"Content-Type" => "application/json"})
  end

  def build_token(claims)
    JWT.encode(
      claims,
      signing_key,
      "EdDSA",
      { kid: kid },
    )
  end

  describe "#verify" do
    it "verifies an EdDSA JWT signed with an OKP JWKS key" do
      token = build_token(
        "sub" => "user_eddsa_test",
        "sid" => "sess_abc",
        "iss" => issuer,
        "aud" => audience,
        "exp" => Time.now.to_i + 3600,
      )

      payload = described_class.new(api_url: api_url, issuer: issuer, audience: audience).verify(token)

      expect(payload["sub"]).to eq("user_eddsa_test")
      expect(payload["sid"]).to eq("sess_abc")
    end

    it "loads production JWKS key shape from identity.authio.com" do
      production_jwks = JSON.parse(
        File.read(File.join(__dir__, "fixtures/production_jwks.json")),
      )
      jwk_set = JWT::JWK::Set.new(production_jwks)
      key = jwk_set.find { |jwk| jwk[:kid] == "iDiV3dwIwc_F" }

      expect(key[:alg]).to eq("EdDSA")
      expect(key[:crv]).to eq("Ed25519")
      expect(key.verify_key).to be_a(Ed25519::VerifyKey)
    end

    it "raises when sub is missing" do
      token = build_token(
        "iss" => issuer,
        "aud" => audience,
        "exp" => Time.now.to_i + 3600,
      )

      expect {
        described_class.new(api_url: api_url, issuer: issuer, audience: audience).verify(token)
      }.to raise_error(/token missing sub/)
    end
  end
end
