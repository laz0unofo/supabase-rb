# frozen_string_literal: true

require_relative "lib/supabase/auth/version"

Gem::Specification.new do |spec|
  spec.name = "supabase-auth"
  spec.version = Supabase::Auth::VERSION
  spec.authors = ["Guilherme Souza"]
  spec.email = ["guilherme@grds.dev"]

  spec.summary = "Ruby client for Supabase Auth (GoTrue)"
  spec.description = "A Ruby client library for Supabase Auth providing sign-up, sign-in, OAuth, OTP, MFA, session management, and admin APIs."
  spec.homepage = "https://github.com/grdsdev/supabase-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/grdsdev/supabase-rb/tree/main/gems/supabase-auth"
  spec.metadata["changelog_uri"] = "https://github.com/grdsdev/supabase-rb/blob/main/gems/supabase-auth/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
end
