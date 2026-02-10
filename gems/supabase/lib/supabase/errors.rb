# frozen_string_literal: true

module Supabase
  class SupabaseError < StandardError
    attr_reader :context

    def initialize(message = nil, context: nil)
      @context = context
      super(message)
    end
  end

  class AuthNotAvailableError < SupabaseError; end
end
