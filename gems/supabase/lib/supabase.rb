# frozen_string_literal: true

require_relative "supabase/version"
require_relative "supabase/errors"
require_relative "supabase/url_builder"
require_relative "supabase/sub_clients"
require_relative "supabase/delegation"
require_relative "supabase/auth_token_manager"
require_relative "supabase/client"

require "supabase/auth"
require "supabase/postgrest"
require "supabase/realtime"
require "supabase/storage"
require "supabase/functions"

module Supabase
  def self.create_client(url, key, **)
    Client.new(url, key, **)
  end
end
