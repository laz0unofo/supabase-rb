# frozen_string_literal: true

require "json"

module Supabase
  module Realtime
    # Encodes/decodes Phoenix protocol messages.
    # Phoenix v2 message format: [join_ref, ref, topic, event, payload]
    module Serializer
      module_function

      def encode(message)
        JSON.generate(message)
      end

      def decode(raw)
        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
