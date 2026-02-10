# frozen_string_literal: true

module Supabase
  module PostgREST
    # Error returned by PostgREST when a query fails.
    # Contains structured fields matching the PostgREST error response format.
    class PostgrestError < StandardError
      attr_reader :details, :hint, :code

      def initialize(message = nil, details: nil, hint: nil, code: nil)
        @details = details
        @hint = hint
        @code = code
        super(message)
      end
    end
  end
end
