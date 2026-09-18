# frozen_string_literal: true

module Authio
  class Configuration
    attr_accessor :api_key, :api_url, :publishable_key, :issuer, :audience,
                  :project_id

    def initialize
      @api_key = ""
      @api_url = "https://api.authio.com"
      @publishable_key = ""
      @issuer = nil
      @audience = "authio"
      # Tenant binding. auth-core signs every tenant's tokens with one
      # platform key under one fixed issuer/audience, so project_id is the
      # only claim saying a token was minted for you rather than in
      # someone else's Authio project — and sign-up is self-serve, so a
      # valid foreign token is free to obtain. Defaults from the env var
      # the docs already ask for.
      @project_id = ENV["AUTHIO_PROJECT_ID"]&.strip
      @project_id = nil if @project_id == ""
    end

    def effective_issuer
      @issuer || @api_url.to_s.sub(%r{/+\z}, "")
    end

    def effective_api_url
      @api_url.to_s.sub(%r{/+\z}, "")
    end
  end
end
