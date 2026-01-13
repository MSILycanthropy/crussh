# frozen_string_literal: true

require "active_support/callbacks"
require "active_support/rescuable"

module Crussh
  class Handler
    include ActiveSupport::Callbacks
    include ActiveSupport::Rescuable

    define_callbacks :handle

    class << self
      def before(*methods, **options, &block)
        set_callback(:handle, :before, *methods, **options, &block)
      end

      def after(*methods, **options, &block)
        set_callback(:handle, :after, *methods, **options, &block)
      end

      def around(*methods, **options, &block)
        set_callback(:handle, :around, *methods, **options, &block)
      end
    end

    def initialize(channel, session, ...)
      channel.__internal_set_on_resize { |width, height| handle_resize(width, height) }
      channel.__internal_set_on_signal { |name| handle_signal(name) }

      @channel = channel
      @session = session

      setup(...)
    end

    def setup(...); end

    def call
      run_callbacks(:handle) { handle }
    rescue => e
      rescue_with_handler(e) || raise
    end

    def handle_resize(width, height); end
    def handle_signal(name); end

    private

    attr_reader :session

    def user = session.user
    def config = session.config
    def pty = channel.pty
    def pty? = channel.pty?
    def env = channel.env

    def logger
      # TODO: Some sort of logging context
      @logger ||= Logger
    end

    def puts(...) = channel.puts(...)
    def print(...) = channel.print(...)
    def gets(...) = channel.gets(...)
    def read(...) = channel.read(...)
    def write(...) = channel.write(...)

    def close = channel.close
    def send_eof = channel.send_eof
    def exit_status(...) = channel.exit_status(...)
    def exit_signal(...) = channel.exit_signal(...)

    def print_prompt(prompt)
      case prompt
      when String then print(prompt)
      when Proc then print(prompt.call)
      end
    end

    protected

    attr_reader(:channel)
  end
end
