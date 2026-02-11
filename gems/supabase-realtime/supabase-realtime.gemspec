# frozen_string_literal: true

require_relative "lib/supabase/realtime/version"

Gem::Specification.new do |spec|
  spec.name = "supabase-realtime"
  spec.version = Supabase::Realtime::VERSION
  spec.authors = ["Guilherme Souza"]
  spec.email = ["guilherme@grds.dev"]

  spec.summary = "Ruby client for Supabase Realtime"
  spec.description = "A Ruby client library for Supabase Realtime providing WebSocket-based broadcast, presence, and PostgreSQL change data capture."
  spec.homepage = "https://github.com/grdsdev/supabase-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/grdsdev/supabase-rb/tree/main/gems/supabase-realtime"
  spec.metadata["changelog_uri"] = "https://github.com/grdsdev/supabase-rb/blob/main/gems/supabase-realtime/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "websocket-client-simple", "~> 0.8"
end
