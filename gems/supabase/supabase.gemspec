# frozen_string_literal: true

require_relative "lib/supabase/version"

Gem::Specification.new do |spec|
  spec.name = "supabase"
  spec.version = Supabase::VERSION
  spec.authors = ["Guilherme Souza"]
  spec.email = ["guilherme@grds.dev"]

  spec.summary = "Ruby SDK for Supabase"
  spec.description = "A complete Ruby SDK for Supabase composing Auth, PostgREST, Realtime, Storage, and Functions clients into a single interface."
  spec.homepage = "https://github.com/grdsdev/supabase-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/grdsdev/supabase-rb/tree/main/gems/supabase"
  spec.metadata["changelog_uri"] = "https://github.com/grdsdev/supabase-rb/blob/main/gems/supabase/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "supabase-auth", "~> 0.1"
  spec.add_dependency "supabase-functions", "~> 0.1"
  spec.add_dependency "supabase-postgrest", "~> 0.1"
  spec.add_dependency "supabase-realtime", "~> 0.1"
  spec.add_dependency "supabase-storage", "~> 0.1"
end
