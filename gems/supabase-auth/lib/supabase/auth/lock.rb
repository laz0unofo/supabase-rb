# frozen_string_literal: true

module Supabase
  module Auth
    # Process-level mutex lock for serializing concurrent session operations.
    # Prevents race conditions when multiple threads access the session simultaneously.
    class Lock
      DEFAULT_TIMEOUT = 10

      def initialize(timeout: DEFAULT_TIMEOUT)
        @timeout = timeout
        @mutex = Mutex.new
      end

      # Acquires the lock and yields to the block.
      # Times out after the configured timeout period.
      def with_lock(&)
        acquired = false
        deadline = Time.now + @timeout

        until acquired
          acquired = @mutex.try_lock
          next if acquired

          remaining = deadline - Time.now
          raise Timeout::Error, "Lock acquisition timed out after #{@timeout}s" if remaining <= 0

          sleep(0.01)
        end

        yield
      ensure
        @mutex.unlock if acquired && @mutex.owned?
      end
    end
  end
end
