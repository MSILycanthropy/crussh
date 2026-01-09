# frozen_string_literal: true

require "English"
require "io/stream"

module Crussh
  class Channel
    DEFAULT_WINDOW_SIZE = 2 * 1014 * 1024
    DEFAULT_MAX_PACKET_SIZE = 32_768

    Data = ::Data.define(:data)
    ExtendedData = ::Data.define(:data, :type)
    WindowChange = ::Data.define(:width, :height, :pixel_width, :pixel_height)
    Signal = ::Data.define(:name)
    EOF = ::Data.define
    Closed = ::Data.define

    Pty = ::Data.define(:term, :width, :height, :pixel_width, :pixel_height, :modes)

    def initialize(session:, id:, remote_id:, remote_window_size:, local_window_size:, max_packet_size:)
      @session = session
      @id = id
      @remote_id = remote_id

      @reader = Reader.new(
        session:,
        remote_id:,
        window_size: local_window_size,
      )

      @writer = Writer.new(
        session:,
        remote_id:,
        max_packet_size:,
        window_size: remote_window_size,
        channel: self,
      )

      @pty = nil
      @env = {}
      @events = Async::Queue.new
      @read_buffer = "".b
    end

    attr_reader :session, :id, :remote_id, :pty, :env
    attr_writer :pty

    def pty? = !@pty.nil?
    def eof? = @reader.eof?
    def closed? = @writer.closed?

    def read(...) = @reader.read(...)
    def readpartial(...) = @reader.readpartial(...)
    def gets(...) = @reader.gets(...)
    def each(&) = @reader.each(&)

    def write(...) = @writer.write(...)
    def puts(...) = @writer.puts(...)
    def print(...) = @writer.print(...)
    def flush = @writer.flush

    def <<(data)
      write(data)
      self
    end

    def send_eof = @writer.send_eof
    def close = @writer.close

    def stderr
      @stderr ||= Stderr.new(session:, remote_id:)
    end

    def exit_status(code)
      message = Protocol::ChannelRequest.new(recipient_channel: @remote_id, request_type: "exit-status", want_reply: false, request_data: [code].pack("N"))
      @session.write_packet(message)
    end

    def exit_signal(signal_name, core_dumped: false, error_message: "", language: "")
      writer = Transport::Writer.new
      writer.string(signal_name)
      writer.boolean(core_dumped)
      writer.string(error_message)
      writer.string(language)

      message = Protocol::ChannelRequest.new(recipient_channel: @remote_id, request_type: "exit-signal", want_reply: false, request_data: writer.to_s)
      @session.write_packet(message)
    end

    def push_event(event) = @reader.push_event(event)
    def adjust_remote_window(bytes) = @writer.adjust_window(bytes)

    def set_env(name, value)
      @env[name] = value
    end

    def update_window(window_change)
      @pty = @pty.with(width: window_change.width, height: window_change.height, pixel_width: window_change.pixel_width, pixel_height: window_change.pixel_height) if @pty
      push_event(window_change)
    end

    class Reader
      def initialize(session:, remote_id:, window_size:)
        @session = session
        @remote_id = remote_id
        @window_size = window_size
        @window_threshold = window_size / 2
        @bytes_consumed = 0

        @events = Async::Queue.new
        @buffer = "".b

        @eof = false
        @closed = false
      end

      def eof? = @eof
      def closed? = @closed

      def push_event(event)
        @events.enqueue(event)
      end

      def each
        return enum_for(:each) unless block_given?

        loop do
          event = @events.dequeue
          yield event
          break if event.is_a?(Closed)
        end
      end

      def read(length = nil)
        return drain_buffer(length) if length && @buffer.bytesize >= length

        loop do
          event = @events.dequeue

          case event
          when Data(data:)
            consume_window(data.bytesize)
            @buffer << data
            return drain_buffer(length) if length && @buffer.bytesize >= length
          when EOF
            @eof = true

            return @buffer.empty? ? nil : drain_buffer(length)
          when Closed
            @closed = true

            return @buffer.empty? ? nil : drain_buffer(length)
          end
        end
      end

      def readpartial(maxlen, outbuf = nil)
        outbuf ||= "".b
        outbuf.clear

        if @buffer.bytesize > 0
          outbuf << drain_buffer(maxlen)
          return outbuf
        end

        loop do
          event = @events.dequeue

          case event
          when Data(data:)
            consume_window(data.bytesize)
            @buffer << data
            outbuf << drain_buffer(maxlen)
            return outbuf
          when EOF
            @eof = true
            raise ::EOFError, "end of file reached"
          when Closed
            @closed = true
            raise ::IOError, "channel closed"
          end
        end
      end

      def gets(sep = $INPUT_RECORD_SEPARATOR, limit = nil)
        loop do
          if (index = @buffer.index(sep))
            return @buffer.slice!(0, index + sep.bytesize)
          end

          return drain_buffer if limit && @buffer.bytesize >= limit

          event = @events.dequeue

          case event
          when Data
            consume_window(event.data.bytesize)
            @buffer << event.data
          when EOF
            @eof = true
            return @buffer.empty? ? nil : @buffer.slice!(0..-1)
          when Closed
            @closed = true
            return @buffer.empty? ? nil : @buffer.slice!(0..-1)
          end
        end
      end

      private

      def drain_buffer(length = nil)
        @buffer.slice!(0, length || @buffer.bytesize)
      end

      def consume_window(bytes)
        @bytes_consumed += bytes

        return if @bytes_consumed < @window_threshold

        message = Protocol::ChannelWindowAdjust.new(
          recipient_channel: @remote_id,
          bytes_to_add: @bytes_consumed,
        )

        @session.write_packet(message)
        @bytes_consumed = 0
      end
    end

    module WriteMethods
      def line_ending
        "\n"
      end

      def puts(*args)
        if args.empty?
          write(line_ending)
          return
        end

        buffer = "".b
        args.each do |arg|
          line = arg.to_s
          buffer << line
          buffer << line_ending unless line.end_with?("\n")
        end
        write(buffer)
        nil
      end

      def print(*args)
        args.each { |arg| write(arg.to_s) }
        nil
      end

      def <<(data)
        write(data)
        self
      end

      def flush = self
    end

    class Writer
      include WriteMethods

      def initialize(session:, remote_id:, max_packet_size:, window_size:, channel:)
        @session = session
        @remote_id = remote_id
        @max_packet_size = max_packet_size
        @window_size = window_size
        @channel = channel

        @window_condition = Async::Condition.new

        @eof_sent = false
        @closed = false
      end

      def closed? = @closed

      def line_ending
        @channel.pty? ? "\r\n" : "\n"
      end

      def adjust_window(bytes)
        @window_size += bytes
        @window_condition.signal
      end

      def write(data)
        raise ::IOError, "channel closed" if @closed
        raise ::IOError, "EOF already sent" if @eof_sent

        data = data.to_s.b
        bytes_written = 0

        while bytes_written < data.bytesize
          @window_condition.wait if @window_size <= 0

          chunk_size = [
            @max_packet_size,
            @window_size,
            data.bytesize - bytes_written,
          ].min
          chunk = data.byteslice(bytes_written, chunk_size)

          message = Protocol::ChannelData.new(recipient_channel: @remote_id, data: chunk)
          @session.write_packet(message)

          @window_size -= chunk_size
          bytes_written += chunk_size
        end

        bytes_written
      end

      def send_eof
        return if @eof_sent

        @eof_sent = true

        message = Protocol::ChannelEof.new(recipient_channel: @remote_id)
        @session.write_packet(message)
      end

      def close
        return if @closed

        send_eof unless @eof_sent
        @closed = true

        message = Protocol::ChannelClose.new(recipient_channel: @remote_id)
        @session.write_packet(message)
      end
    end

    class Stderr
      include WriteMethods

      def initialize(session:, remote_id:)
        @session = session
        @remote_id = remote_id
      end

      def write(data)
        data = data.to_s.b

        message = Protocol::ChannelExtendedData.new(
          recipient_channel: @remote_id,
          data_type_code: 1,
          data: data,
        )
        @session.write_packet(message)

        data.bytesize
      end
    end
  end
end
