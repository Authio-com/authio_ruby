# frozen_string_literal: true

module Authio
  class Configuration
    attr_accessor :api_key, :api_url, :publishable_key, :issuer, :audience

    def initialize
      @api_key = ""
      @api_url = "https://api.authio.com"
      @publishable_key = ""
      @issuer = nil
      @audience = "authio"
    end

    def effective_issuer
      @issuer || @api_url.to_s.sub(%r{/+\z}, "")
    end

    def effective_api_url
      @api_url.to_s.sub(%r{/+\z}, "")
    end
  end
end
