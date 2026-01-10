# frozen_string_literal: true

module Crussh
  class Gatekeeper
    def initialize(max_connections:, max_unauthenticated:)
      @max_connections = max_connections
      @max_unauthenticated = max_unauthenticated

      @mutex = Mutex.new
      @total = 0
      @unauthenticated = 0
    end

    attr_reader :total, :unauthenticated

    def block? = !allowed?

    def authenticate!
      @mutex.synchronize do
        @unauthenticated -= 1 if @unauthenticated > 0
      end
    end

    def disconnect!(was_authenticated:)
      @mutex.synchronize do
        @total -= 1 if @total > 0
        @unauthenticated -= 1 if !was_authenticated && @unauthenticated > 0
      end
    end

    def stats
      @mutex.synchronize do
        { total: @total, unauthenticated: @unauthenticated }
      end
    end

    private

    def allowed?
      @mutex.synchronize do
        return false if @max_connections && @total >= @max_connections
        return false if @max_unauthenticated && @unauthenticated >= @max_unauthenticated

        @total += 1
        @unauthenticated += 1
        true
      end
    end
  end
end
