# frozen_string_literal: true

require_relative "lib/authio/version"

Gem::Specification.new do |spec|
  spec.name = "authio"
  spec.version = Authio::VERSION
  spec.authors = ["Authio"]
  spec.email = ["dev@authio.com"]

  spec.summary = "Authio Ruby SDK — passwordless, multi-org auth for B2B Rails apps."
  spec.description = "Verify Authio session JWTs against the JWKS, mint magic-link sign-in URLs, " \
                     "and integrate with Rails controllers via `before_action :authenticate_authio!`."
  spec.homepage = "https://github.com/Authio-com/authio_ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE", "authio.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_dependency "jwt", "~> 2.7"

  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "webmock", "~> 3.18"
end
