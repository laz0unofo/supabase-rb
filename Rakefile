# frozen_string_literal: true

require "rspec/core/rake_task"

GEMS = %w[
  supabase-functions
  supabase-postgrest
  supabase-storage
  supabase-auth
  supabase-realtime
  supabase
].freeze

GEMS.each do |gem_name|
  namespace gem_name.tr("-", "_") do
    RSpec::Core::RakeTask.new(:spec) do |t|
      t.pattern = "gems/#{gem_name}/spec/**/*_spec.rb"
      t.rspec_opts = "-I gems/#{gem_name}/spec -I gems/#{gem_name}/lib"
    end
  end
end

desc "Run specs for all gems"
task :spec do
  GEMS.each do |gem_name|
    puts "\n=== Running specs for #{gem_name} ==="
    Rake::Task["#{gem_name.tr("-", "_")}:spec"].invoke
  end
end

task default: :spec
