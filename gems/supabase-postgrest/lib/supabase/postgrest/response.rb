# frozen_string_literal: true

module Supabase
  module PostgREST
    # Value object representing a successful PostgREST response.
    # Returned by execute on success; errors raise PostgrestError instead.
    class Response
      attr_reader :data, :count, :status, :status_text

      def initialize(data:, count:, status:, status_text:)
        @data = data
        @count = count
        @status = status
        @status_text = status_text
      end
    end
  end
end
