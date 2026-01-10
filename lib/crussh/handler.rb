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

    def resize(...); end

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

    def each_event(...) = channel.each(...)

    def each_key(&block)
      return enum_for(:each_key) unless block_given?

      parser = Channel::KeyParser.new

      each_event do |event|
        case event
        when Channel::Data
          event.each_key(parser: parser, &block)
        when Channel::WindowChange
          resize(event.width, event.height) if respond_to?(:resize, true)
        when Channel::EOF
          yield :eof
        when Channel::Closed
          return
        end
      end
    end

    def each_line(prompt: "", echo: true)
      return enum_for(:each_line, prompt:, echo:) unless block_given?

      buffer = LineBuffer.new(channel, echo:)
      print_prompt(prompt)

      each_key do |key|
        case key
        when :enter
          puts if echo
          line = buffer.flush
          yield line unless line.empty?
          print_prompt(prompt)
        when :interrupt
          puts if echo
          buffer.clear
          print_prompt(prompt)
        when :eof
          puts if echo
          return
        else
          buffer.handle(key)
        end
      end
    end

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
