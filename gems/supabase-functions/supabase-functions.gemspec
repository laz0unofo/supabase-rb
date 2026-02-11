# frozen_string_literal: true

require_relative "lib/supabase/functions/version"

Gem::Specification.new do |spec|
  spec.name = "supabase-functions"
  spec.version = Supabase::Functions::VERSION
  spec.authors = ["Guilherme Souza"]
  spec.email = ["guilherme@grds.dev"]

  spec.summary = "Ruby client for Supabase Edge Functions"
  spec.description = "A Ruby client library for invoking Supabase Edge Functions with automatic body serialization, response parsing, and error handling."
  spec.homepage = "https://github.com/grdsdev/supabase-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/grdsdev/supabase-rb/tree/main/gems/supabase-functions"
  spec.metadata["changelog_uri"] = "https://github.com/grdsdev/supabase-rb/blob/main/gems/supabase-functions/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
end
