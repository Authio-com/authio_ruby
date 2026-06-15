# frozen_string_literal: true

require "authio"

RSpec.describe Authio::Client do
  before do
    Authio.reset_configuration!
    Authio.configure do |c|
      c.api_key = "sk_test"
      c.api_url = "https://api.example.test"
      c.publishable_key = "pk_test_xyz"
    end
    Authio::Client.reset_default!
  end

  describe "#verify_token" do
    subject(:client) { Authio::Client.new }

    it "returns nil for an empty token" do
      expect(client.verify_token(nil)).to be_nil
      expect(client.verify_token("")).to be_nil
    end

    it "returns nil for an invalid JWT" do
      expect(client.verify_token("not-a-real-jwt")).to be_nil
    end

    it "decodes a stubbed JWKS payload into a Session" do
      verifier = client.instance_variable_get(:@verifier)
      allow(verifier).to receive(:verify).and_return({
        "sub" => "user_123",
        "sid" => "sess_abc",
        "act_org" => "org_xyz",
        "act_role" => "admin",
        "exp" => Time.now.to_i + 3600,
        "iss" => "https://api.example.test",
        "aud" => "authio",
        "custom_claim" => "value",
      })

      session = client.verify_token("anything")
      expect(session).not_to be_nil
      expect(session.user_id).to eq("user_123")
      expect(session.session_id).to eq("sess_abc")
      expect(session.org_id).to eq("org_xyz")
      expect(session.role).to eq("admin")
      expect(session.claims["custom_claim"]).to eq("value")
      expect(session.claims["iss"]).to be_nil
    end
  end

  describe "#sign_in_url" do
    it "URL-encodes the publishable key and redirect" do
      url = Authio::Client.new.sign_in_url(redirect_url: "https://app.example/dashboard?x=1")
      expect(url).to include("publishable_key=pk_test_xyz")
      expect(url).to include("redirect_url=https%3A%2F%2Fapp.example%2Fdashboard%3Fx%3D1")
    end
  end
end
