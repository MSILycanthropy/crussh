# frozen_string_literal: true

module Crussh
  class Server
    module Layers
      class Userauth
        def initialize(session)
          @session = session
          @authenticated_user = nil
          @attempts = 0
          @first_attempt = true
        end

        attr_reader :authenticated_user

        def run(task: Async::Task.current)
          timeout = config.auth_timeout || config.connection_timeout

          task.with_timeout(timeout) do
            service_request
            send_banner
            authenticate
          end
        rescue Async::TimeoutError
          Logger.warn(self, "Authentication timeout")
        end

        private

        def config = @session.config
        def server = @session.server
        def session_id = @session.id

        def supported_methods
          server.auth_methods.map(&:to_s)
        end

        def service_request
          packet = @session.read_packet
          request = Protocol::ServiceRequest.parse(packet)

          Logger.debug(self, "Service request", service: request.service_name)

          unless request.service_name == "ssh-userauth"
            raise ProtocolError, "Unknown service: #{request.service_name}"
          end

          accept = Protocol::ServiceAccept.new(service_name: "ssh-userauth")
          @session.write_packet(accept)

          Logger.debug(self, "Service accepted", service: "ssh-userauth")
        end

        def send_banner
          banner = server.banner

          return if banner.nil?

          packet = Protocol::UserauthBanner.new(message: banner)
          @session.write_packet(packet)
          Logger.debug(self, "Banner sent")
        end

        def authenticate
          loop do
            packet = @session.read_packet
            message_type = packet.getbyte(0)

            case message_type
            when Protocol::USERAUTH_REQUEST
              handle_auth_request(packet)&.then { return }
            when Protocol::DISCONNECT
              Logger.debug(self, "Client disconnected during auth")
              session.close
              return
            else
              Logger.warn(self, "Unknown message type during authentication", message_type:)
              unimplemented = Packet::Unimplemented.new(sequence_number: @session.last_read_sequence)
              @session.write_packet(unimplemented)
            end
          end
        end

        def handle_auth_request(packet)
          request = Protocol::UserauthRequest.parse(packet)

          Logger.debug(
            self,
            "Auth request",
            user: request.username,
            service: request.service_name,
            method: request.method_name,
          )

          result = dispatch_auth(request)

          case result
          when :success
            handle_successful_auth(request)
            true
          when :pk_ok
            Logger.debug(self, "Public key accepted", user: request.username)
            nil
          when :failure
            handle_failed_auth(request)
            nil
          end
        end

        def dispatch_auth(request)
          method = request.method_name.to_sym

          case method
          when :none
            handle_none(request)
          when :password
            handle_password(request)
          when :publickey
            handle_publickey(request)
          when :keyboard_interactive
            :failure
          else
            Logger.warn(self, "Unknown auth method", method: request.method_name)
            :failure
          end
        end

        def handle_none(request)
          server.handle_auth(:none, request.username) ? :success : :failure
        end

        def handle_password(request)
          server.handle_auth(:password, request.username, request.password) ? :success : :failure
        end

        def handle_publickey(request)
          pk_data = request.public_key_data
          public_key = Keys.parse_public_blob(pk_data.key_blob)

          unless pk_data.has_signature?
            acceptable = server.handle_auth(:publickey, request.username, public_key)

            if acceptable
              pk_ok = Protocol::UserauthPkOk.new(
                algorithm: pk_data.algorithm,
                key_blob: pk_data.key_blob,
              )
              @session.write_packet(pk_ok)

              Logger.debug(self, "PK_OK sent", algorithm: pk_data.algorithm)

              :pk_ok
            else
              :failure
            end
          end

          signed = build_signed_data(request, pk_data)

          if public_key.verify(signed, pk_data.signature)
            :success
          else
            :failure
          end
        end

        def handle_successful_auth(request)
          @authenticated_user = request.username
          @session.write_packet(Protocol::UserauthSuccess.new)
          server.auth_succeeded(request.username) if server.respond_to?(:auth_succeeded)

          @session.enable_compression

          Logger.info(
            self,
            "Authentication successful",
            user: request.username,
            method: request.method_name,
          )
        end

        def handle_failed_auth(request)
          @attempts += 1

          rejection_time = if initial?(request)
            config.auth_rejection_time_initial
          else
            config.auth_rejection_time
          end

          @first_attempt = false

          sleep(rejection_time) if rejection_time&.positive?

          packet = Protocol::UserauthFailure.new(authentications: supported_methods)
          @session.write_packet(packet)

          return if @attempts < config.max_auth_attempts

          @session.disconnect(:no_more_auth_methods_available, "Too many authentication failures")
        end

        def build_signed_data(request, pk_data)
          writer = Crussh::Transport::Writer.new
          writer.string(session_id)
          writer.byte(Protocol::USERAUTH_REQUEST)
          writer.string(request.username)
          writer.string(request.service_name)
          writer.string("publickey")
          writer.boolean(true)
          writer.string(pk_data.algorithm)
          writer.string(pk_data.key_blob)
          writer.to_s
        end

        def initial?(request)
          @first_attempt && request.none?
        end
      end
    end
  end
end
