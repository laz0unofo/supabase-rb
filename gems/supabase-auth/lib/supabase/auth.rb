# frozen_string_literal: true

require_relative "auth/version"
require_relative "auth/errors"
require_relative "auth/jwt"
require_relative "auth/pkce"
require_relative "auth/memory_storage"
require_relative "auth/session"
require_relative "auth/lock"
require_relative "auth/error_classifier"
require_relative "auth/subscription"
require_relative "auth/client"

module Supabase
  module Auth
  end
end
