# frozen_string_literal: true

require_relative "realtime/version"
require_relative "realtime/errors"
require_relative "realtime/serializer"
require_relative "realtime/push"
require_relative "realtime/heartbeat"
require_relative "realtime/reconnect"
require_relative "realtime/presence"
require_relative "realtime/channel_message_handler"
require_relative "realtime/broadcast_methods"
require_relative "realtime/presence_methods"
require_relative "realtime/postgres_changes_methods"
require_relative "realtime/channel"
require_relative "realtime/client"

module Supabase
  module Realtime
  end
end
