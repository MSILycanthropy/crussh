# frozen_string_literal: true

module Crussh
  # Thresholds for when to perform key re-exchange.
  # Rekeying is important for long-lived connections to limit
  # the amount of data encrypted under a single key.
  class Limits
    ONE_GB = 1 << 30
    ONE_HOUR = 3600

    attr_accessor :rekey_write_limit,
      :rekey_read_limit,
      :rekey_time_limit

    # defaults from
    # https://datatracker.ietf.org/doc/html/rfc4253#section-9
    def initialize(
      rekey_write_limit: ONE_GB,
      rekey_read_limit: ONE_GB,
      rekey_time_limit: ONE_HOUR
    )
      @rekey_write_limit = rekey_write_limit
      @rekey_read_limit = rekey_read_limit
      @rekey_time_limit = rekey_time_limit
    end
  end
end
