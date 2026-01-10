# frozen_string_literal: true

module Crussh
  class Heartbeat
    KEEPALIVE_REQUEST = "keepalive@openssh.com"

    def initialize(session, interval:, max:)
      @session = session
      @interval = interval
      @max = max
      @missed = 0
      @last_activity = Time.now
      @task = nil
    end

    attr_reader :missed

    def start(task: Async::Task.current)
      return if @interval.nil?

      @task = task.async do
        loop do
          sleep(@interval)

          if time_since_last_activity >= @interval
            @missed += 1

            if session_unresponsive?
              @session.disconnect(:connection_lost, "Keepalive timeout")
              break
            end

            send_keepalive
          end
        end
      end
    end

    def stop
      @task&.stop
    end

    def record_activity!
      @last_activity = Time.now
      @missed = 0
    end

    private

    def send_keepalive
      message = Protocol::GlobalRequest.new(
        request_type: KEEPALIVE_REQUEST,
      )
      @session.write_packet(message)
    rescue IOError, Errno::ECONNRESET, ConnectionClosed
      stop
    end

    def session_unresponsive?
      @missed > @max
    end

    def time_since_last_activity
      Time.now - @last_activity
    end
  end
end
