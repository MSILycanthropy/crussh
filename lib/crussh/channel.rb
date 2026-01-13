# frozen_string_literal: true

require "English"
require "io/stream"
require "async/semaphore"

module Crussh
  class Channel
    DEFAULT_WINDOW_SIZE = 2 * 1024 * 1024
    DEFAULT_MAX_PACKET_SIZE = 32_768

    WindowChange = ::Data.define(:width, :height, :pixel_width, :pixel_height)
    Signal = ::Data.define(:name)
    Pty = ::Data.define(:term, :width, :height, :pixel_width, :pixel_height, :modes)

    def initialize(session:, id:, remote_id:, remote_window_size:, local_window_size:, max_packet_size:)
      @session = session
      @id = id
      @remote_id = remote_id

      @reader = Reader.new(
        session:,
        remote_id:,
        window_size: local_window_size,
        channel: self,
      )

      @writer = Writer.new(
        session:,
        remote_id:,
        max_packet_size:,
        window_size: remote_window_size,
        channel: self,
      )

      @pty = nil
      @raw = false
      @env = {}
    end

    attr_reader :session, :id, :remote_id, :pty, :env
    attr_writer :pty

    def pty? = !@pty.nil?
    def eof? = @reader.eof?
    def closed? = @writer.closed?

    def tty? = pty?

    def raw? = @raw

    def raw!
      @raw = true
      self
    end

    def cooked!
      @raw = false
      self
    end

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

    def push_data(data) = @reader.push_data(data)
    def push_eof = @reader.push_eof
    def adjust_remote_window(bytes) = @writer.adjust_window(bytes)

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

    def set_env(name, value)
      @env[name] = value
    end

    def update_window(window_change)
      @pty = @pty.with(width: window_change.width, height: window_change.height, pixel_width: window_change.pixel_width, pixel_height: window_change.pixel_height) if @pty
      push_event(window_change)
    end

    # @api private
    def __internal_set_on_resize(&block) = @on_resize = block
    # @api private
    def __internal_set_on_signal(&block) = @on_signal = block

    class Reader
      def initialize(session:, remote_id:, window_size:, channel:)
        @channel = channel
        @session = session
        @remote_id = remote_id
        @window_size = window_size
        @window_threshold = window_size / 2
        @bytes_consumed = 0

        @reader, @writer = IO.pipe
        @reader.nonblock = true

        @writer.binmode
        @writer.nonblock = true

        @eof = false
      end

      def eof? = @eof

      def read(length = nil, outbuf = nil) = readpartial(length || 4096, outbuf)

      def push_data(data)
        if @channel.pty? && !@channel.raw?
          data = data.gsub("\r\n", "\n")
            .gsub("\r", "\n")
        end

        consume_window(data.bytesize)
        @writer.write(data)
      end

      def readpartial(...) = @reader.readpartial(...)
      def read_nonblock(...) = @reader.read_nonblock(...)
      def wait_readable(...) = @reader.wait_readable(...)
      def gets(...) = @reader.gets(...)

      def push_eof
        @eof = true
        @writer.close
      end

      def close
        @writer.close unless @writer.closed?
        @reader.close unless @reader.closed?
      end

      private

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
        @semaphore = Async::Semaphore.new(1)

        @eof_sent = false
        @closed = false
      end

      def closed? = @closed

      def line_ending
        @channel.pty? && !@channel.raw? ? "\r\n" : "\n"
      end

      def adjust_window(...) = @semaphore.acquire { adjust_window_inner(...) }
      def write(...) = @semaphore.acquire { write_inner(...) }
      def send_eof = @semaphore.acquire { send_eof_inner }
      def close = @semaphore.acquire { close_inner }

      private

      def adjust_window_inner(bytes)
        @window_size += bytes
        @window_condition.signal
      end

      def close_inner
        return if @closed

        send_eof_inner unless @eof_sent
        @closed = true

        message = Protocol::ChannelClose.new(recipient_channel: @remote_id)
        @session.write_packet(message)
      end

      def send_eof_inner
        return if @eof_sent

        @eof_sent = true

        message = Protocol::ChannelEof.new(recipient_channel: @remote_id)
        @session.write_packet(message)
      end

      def write_inner(data)
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
    end

    class Stderr
      include WriteMethods

      def initialize(session:, remote_id:)
        @session = session
        @remote_id = remote_id
        @semaphore = Async::Semaphore.new(1)
      end

      def write(...) = @semaphore.acquire { write_inner(...) }

      private

      def write_inner(data)
        data = data.to_s.b

        message = Protocol::ChannelExtendedData.new(
          recipient_channel: @remote_id,
          data_type_code: 1,
          data:,
        )
        @session.write_packet(message)

        data.bytesize
      end
    end
  end
end
