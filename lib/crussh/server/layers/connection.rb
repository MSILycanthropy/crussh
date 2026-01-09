# frozen_string_literal: true

module Crussh
  class Server
    module Layers
      class Connection
        def initialize(session)
          @session = session
          @channels = {}
          @next_channel_id = 0
        end

        def run(task: Async::Task.current)
          loop do
            packet = read_with_timeout

            break if packet.nil?

            dispatch(packet)
          end
        end

        private

        def config = @session.config
        def server = @session.server
        def packet_stream = @session.packet_stream

        def read_with_timeout(task: Async::Task.current)
          return @session.read_packet if config.inactivity_timeout.nil?

          task.with_timeout(config.inactivity_timeout) do
            @session.read_packet
          end
        rescue Async::TimeoutError
          nil
        end

        def dispatch(packet)
          message_type = packet.getbyte(0)

          case message_type
          when Protocol::CHANNEL_OPEN
            channel_open(packet)
          when Protocol::CHANNEL_DATA
            channel_data(packet)
          when Protocol::CHANNEL_EXTENDED_DATA
            channel_extended_data(packet)
          when Protocol::CHANNEL_EOF
            channel_eof(packet)
          when Protocol::CHANNEL_CLOSE
            channel_close(packet)
          when Protocol::CHANNEL_REQUEST
            channel_request(packet)
          when Protocol::CHANNEL_WINDOW_ADJUST
            window_adjust(packet)
          when Protocol::GLOBAL_REQUEST
            global_request(packet)
          when Protocol::DISCONNECT
            disconnect(packet)
          else
            Logger.warn(self, "Unhandled message type", type: message_type)
            message = Protocol::Unimplemented.new(sequence_number: @session.last_read_sequence)
            @session.write_packet(message)
          end
        end

        def channel_open(packet, task: Async::Task.current)
          message = Protocol::ChannelOpen.parse(packet)
          channel_type = message.channel_type.to_sym

          unless server.accepts_channel?(channel_type)
            send_channel_open_failure(message.sender_channel, :unknown_channel_type)
            return
          end

          channel = create_channel(remote_id: message.sender_channel, window_size: message.initial_window_size, max_packet_size: message.maximum_packet_size)

          if channel.nil?
            send_channel_open_failure(message.sender_channel, :resource_shortage)
            return
          end

          target = case message.channel_type
          when "direct-tcpip"
            message.direct_tcpip
          when "forwarded-tcpip"
            message.forwarded_tcpip
          when "x11"
            message.x11
          end

          unless server.open_channel?(channel_type, channel, target)
            send_channel_open_failure(message.sender_channel, :administratively_prohibited)
            @channels.delete(channel.id)
            return
          end

          send_channel_open_confirmation(channel, message.sender_channel)

          run_channel(channel_type, channel, target)
        end

        def create_channel(remote_id:, window_size:, max_packet_size:)
          if @channels.size >= config.max_channels_per_session
            Logger.warn(self, "Channel limit reached", current: @channels.size, max: config.max_channels_per_session)
            return
          end

          id = @next_channel_id
          @next_channel_id += 1

          channel = Channel.new(
            session: @session,
            id: id,
            remote_id: remote_id,
            remote_window_size: window_size,
            local_window_size: config.window_size,
            max_packet_size: [max_packet_size, config.max_packet_size].min,
          )

          @channels[id] = channel
          channel
        end

        def run_channel(channel_type, channel, target)
          case channel_type
          when :session
            nil
          when direct_tcpip
            server.direct_tcpip(channel, target)
          when :forwarded_tcpip
            server.forwarded_tcpip(channel, target)
          when :x11
            server.x11(channel, target)
          end
        rescue => e
          Logger.error(self, "Channel handler error", e)
        end

        def channel_data(packet)
          message = Protocol::ChannelData.parse(packet)
          channel = @channels[message.recipient_channel]
          return if channel.nil?

          channel.push_event(Channel::Data.new(data: message.data))
        end

        def channel_extended_data(packet)
          message = Protocol::ChannelExtendedData.parse(packet)
          channel = @channels[message.recipient_channel]
          return if channel.nil?

          channel.push_event(Channel::ExtendedData.new(data: message.data, type: message.data_type_code))
        end

        def channel_eof(packet)
          message = Protocol::ChannelEof.parse(packet)
          channel = @channels[message.recipient_channel]
          return if channel.nil?

          channel.push_event(Channel::EOF.new)
          server.channel_eof(channel) if server.respond_to?(:channel_eof)
        end

        def channel_close(packet)
          message = Protocol::ChannelClose.parse(packet)
          channel = @channels[message.recipient_channel]
          return if channel.nil?

          channel.close unless channel.closed?
          @channels.delete(channel.id)
          channel.push_event(Channel::Closed.new)
          server.channel_eof(channel) if server.respond_to?(:channel_eof)
        end

        def window_adjust
          message = Protocol::ChannelWindowAdjust.parse(packet)
          channel = @channels[message.recipient_channel]
          return if channel.nil?

          channel.adjust_remote_window(message.bytes_to_add)
        end

        def channel_request(packet)
          message = Protocol::ChannelRequest.parse(packet)
          channel = @channels[message.recipient_channel]

          return if channel.nil?

          accepted = case message.request_type
          when "pty-req"
            pty_request(channel, message)
          when "env"
            env_request(channel, message)
          when "shell"
            shell_request(channel)
          when "exec"
            exec_request(channel, message)
          when "subsystem"
            subsystem_request(channel, message)
          when "window-change"
            window_change(channel, message)
            true
          when "signal"
            signal(channel, message)
            true
          when "x11-req"
            x11_request(channel, message)
          when "auth-agent-req@openssh.com"
            agent_request(channel)
          else
            Logger.warn(self, "Unknown channel request", type: message.request_type)
            false
          end

          return unless message.want_reply?

          message = if accepted
            Protocol::ChannelSuccess.new(recipient_channel: channel.remote_id)
          else
            Protocol::ChannelFailure.new(recipient_channel: channel.remote_id)
          end

          @session.write_packet(message)
        end

        def pty_request(channel, message)
          pty = message.pty

          accepted = server.accepts_request?(:pty, channel, term: pty.term, width: pty.width, height: pty.height, pixel_width: pty.pixel_width, pixel_height: pty.pixel_height, modes: pty.modes)

          channel.pty = pty if accepted

          accepted
        end

        def env_request(channel, message)
          env = message.env

          accepted = server.accepts_request?(:env, channel, name: env.variable_name, value: env.variable_value)

          channel.set_env(env.variable_name, env.variable_value) if accepted

          accepted
        end

        def shell_request(channel)
          return false unless server.respond_to?(:shell)

          Async do
            server.shell(channel)
          end

          true
        end

        def exec_request(channel, message)
          return false unless server.respond_to?(:exec)

          Async do
            server.exec(channel, message.command)
          end

          true
        end

        def subsystem_request(channel, message)
          return false unless server.respond_to?(:subsystem)

          Async do
            server.subsystem(channel, message.subsystem_name)
          end

          true
        end

        def window_change(channel, message)
          window_change = message.window_change

          channel.update_window(window_change)
        end

        def signal(channel, message)
          channel.push_event(message.signal)
        end

        def x11_request
          x11 = message.x11

          server.accepts_request?(:x11, channel, single_connection: x11.single_connection, protocol: x11.auth_protocol, cookie: x11.auth_cookie, screen: x11.screen_number)
        end

        def agent_request(channel)
          server.accepts_request?(:agent, channel)
        end

        def global_request(packet)
          message = Protocol::GlobalRequest.parse(packet)

          accepted = case message.request_type
          when "tcpip-forward"
            tcpip_forward = message.tcpip_forward

            server.respond_to?(:tcpip_forward?) && server.tcpip_forward?(tcpip_forward.address, tcpip_forward.port)
          when "cancel-tcpip-forward"
            tcpip_forward = message.tcpip_forward

            server.respond_to?(:cancel_tcpip_forward?) && server.cancel_tcpip_forward?(tcpip_forward.address, tcpip_forward.port)
          end

          return unless message.want_reply?

          message = if accepted
            Protocol::RequestSuccess.new(response_data: "")
          else
            Protocol::RequestFailure.new
          end

          @session.write_packet(message)
        end

        def disconnect(packet)
          message = Protocol::Disconnect.parse(packet)

          Logger.info(self, "Client disconnected", reason: message.reason_code, description: message.description)
        end

        def send_channel_open_confirmation(channel, recipient_channel)
          message = Protocol::ChannelOpenConfirmation.new(
            recipient_channel:,
            sender_channel: channel.id,
            initial_window_size: config.window_size,
            maximum_packet_size: config.max_packet_size,
          )

          @session.write_packet(message)
        end

        REASON_MAP = {
          administratively_prohibited: 1,
          connect_failed: 2,
          unknown_channel_type: 3,
          resource_shortage: 4,
        }
        DESCRIPTION_MAP = {
          administratively_prohibited: "Admininistravely Prohibited",
          connect_failed: "Connect failed",
          unknown_channel_type: "Unknown channel type",
          resource_shortage: "No more resources, sorry :(",
        }
        def send_channel_open_failure(recipient_channel, reason)
          reason_code = REASON_MAP[reason]
          description = DESCRIPTION_MAP[reason]

          message = Protocol::ChannelOpenFailure.new(recipient_channel:, reason_code:, description:)
          @session.write_packet(message)
        end
      end
    end
  end
end
