# frozen_string_literal: true

require_relative "lib/supabase/storage/version"

Gem::Specification.new do |spec|
  spec.name = "supabase-storage"
  spec.version = Supabase::Storage::VERSION
  spec.authors = ["Guilherme Souza"]
  spec.email = ["guilherme@grds.dev"]

  spec.summary = "Ruby client for Supabase Storage"
  spec.description = "A Ruby client library for Supabase Storage providing bucket management, file operations, signed URLs, and image transforms."
  spec.homepage = "https://github.com/grdsdev/supabase-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/grdsdev/supabase-rb/tree/main/gems/supabase-storage"
  spec.metadata["changelog_uri"] = "https://github.com/grdsdev/supabase-rb/blob/main/gems/supabase-storage/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 2.0"
end
