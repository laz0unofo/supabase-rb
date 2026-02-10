# frozen_string_literal: true

source "https://rubygems.org"

gem "rake", "~> 13.0"
gem "rspec", "~> 3.0"
gem "rubocop", "~> 1.0"
gem "webmock", "~> 3.0"

# Individual gems
%w[
  supabase
  supabase-auth
  supabase-functions
  supabase-postgrest
  supabase-realtime
  supabase-storage
].each do |gem_name|
  gemspec path: "gems/#{gem_name}", name: gem_name
end
