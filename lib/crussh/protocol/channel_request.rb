# frozen_string_literal: true

module Crussh
  module Protocol
    class ChannelRequest < Message
      message_type CHANNEL_REQUEST

      field :recipient_channel, :uint32
      field :request_type, :string
      field :want_reply, :boolean
      field :request_data, :remaining

      def want_reply? = want_reply
      def pty? = request_type == "pty-req"
      def x11? = request_type == "x11-req"
      def env? = request_type == "env"
      def shell? = request_type == "shell"
      def exec? = request_type == "exec"
      def subsystem? = request_type == "subsystem"
      def window_change? = request_type == "window-change"
      def local_flow_control? = request_type == "xon-xoff"
      def signal? = request_type == "signal"
      def exit_status? = request_type == "exit-status"

      def pty
        return @pty_data if @pty_data
        return unless pty?

        reader = Transport::Reader.new(request_data)

        term = reader.string
        width = reader.uint32
        height = reader.uint32
        pixel_width = reader.uint32
        pixel_height = reader.uint32
        modes = reader.string

        @pty_data = Channel::Pty.new(term:, width:, height:, pixel_width:, pixel_height:, modes:)
      end

      def x11
        return @x11_data if @x11_data
        return unless x11?

        reader = Transport::Reader.new(request_data)

        single_connection = reader.boolean
        x11_auth_protocol = reader.string
        x11_auth_cookie = reader.string
        x11_screen_number = reader.uint32

        @x11_data = X11.new(single_connection:, x11_auth_protocol:, x11_auth_cookie:, x11_screen_number:)
      end
      X11 = Data.define(:single_connection, :auth_protocol, :auth_cookie, :screen_number) do
        def single_connection? = single_connection
      end

      def env
        return @env_data if @env_data
        return unless env?

        reader = Transport::Reader.new(request_data)

        variable_name = reader.string
        variable_value = reader.string

        @env_data = Env.new(variable_name:, variable_value:)
      end
      Env = Data.define(:variable_name, :variable_value)

      def command
        return @command if @command
        return unless exec?

        reader = Transport::Reader.new(request_data)
        @comnand = reader.string
      end

      def subsytem_name
        return @subsytem_name if @subsytem_name
        return unless subsystem?

        reader = Transport::Reader.new(request_data)
        @subsytem_name = reader.string
      end

      def window_change
        return @window_change_data if @window_change_data
        return unless window_change?

        reader = Transport::Reader.new(request_data)

        width = reader.uint32
        height = reader.uint32
        pixel_width = reader.uint32
        pixel_height = reader.uint32

        @window_change_data = Channel::WindowChange.new(width:, height:, pixel_width:, pixel_height:)
      end

      def can_do_local_flow_control?
        return @can_do_local_flow_control unless @can_do_local_flow_control.nil?
        return false unless local_flow_control?

        reader = Transport::Reader.new(request_data)

        @can_do_local_flow_control = reader.boolean
      end

      def signal
        return @signal if @signal
        return false unless signal?

        reader = Transport::Reader.new(request_data)

        @signal = Channel::Signal.new(name: reader.string)
      end

      def exit_status
        return @exit_status if @exit_status
        return unless exit_status?

        reader = Transport::Reader.new(request_data)

        @exit_status = reader.uint32
      end

      def exit_signal
        return @exit_signal if @exit_signal
        return unless exit_signal?

        reader = Transport::Reader.new(request_data)

        core_dumped = reader.boolean
        error_message = reader.string
        language_tag = reader.string

        @exit_signal = ExitSignal.new(core_dumped:, error_message:, language_tag:)
      end
      ExitSignal = Data.define(:core_dumped, :error_message, :language_tag) do
        def core_dumped? = core_dumped
      end
    end
  end
end
