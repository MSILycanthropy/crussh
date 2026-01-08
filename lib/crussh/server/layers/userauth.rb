# frozen_string_literal: true

module Crussh
  class Server
    module Layers
      class Userauth
        SUPPORTED_METHODS = ["publickey", "password"].freeze

        def initialize(session)
          @session = session
          @authenticated_user = nil
          @attempts = 0
        end

        attr_reader :authenticated_user

        def run
          service_request
          send_banner
          authenticate
        end

        private

        def config = @session.config
        def handler = @session.handler
        def packet_stream = @session.packet_stream
        def session_id = @session.session_id

        def service_request
          packet = packet_stream.read
          request = Protocol::ServiceRequest.parse(packet)

          Logger.debug(self, "Service request", service: request.service_name)

          unless request.service_name == "ssh-userauth"
            raise ProtocolError, "Unknown service: #{request.service_name}"
          end

          accept = Protocol::ServiceAccept.new(service_name: "ssh-userauth")
          packet_stream.write(accept.serialize)

          Logger.debug(self, "Service accepted", service: "ssh-userauth")
        end

        def send_banner
          banner = handler.auth_banner

          return if banner.nil?

          packet = Protocol::UserauthBanner.new(message: banner)
          packet_stream.write(packet.serialize)
          Logger.debug(self, "Banner sent")
        end

        def authenticate
          loop do
            packet = packet_stream.read
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
              packet = Packet::Unimplemented.new(sequence_number: packet_stream.last_read_sequence)
              packet_stream.write(packet)
            end
          end
        end

        def handle_none(request)
          handler.auth_none(request.username) ? :success : :failure
        end

        def handle_password(request)
          handler.auth_password(request.username, request.password) ? :success : :failure
        end

        def handle_publickey(request)
          pk_data = request.public_key_data

          unless pk_data.has_signature?
            acceptable = handler.auth_publickey_query(
              request.username,
              pk_data.algorithm,
              pk_data.key_blob,
            )

            if acceptable
              pk_ok = Protocol::UserauthPkOk.new(
                algorithm: pk_data.algorithm,
                key_blob: pk_data.key_blob,
              )
              packet_stream.write(pk_ok.serialize)

              Logger.debug(self, "PK_OK sent", algorithm: pk_data.algorithm)

              :pk_ok
            else
              :failure
            end
          end

          if verify_publickey_signature(request, pk_data)
            :success
          else
            :failure
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

          result = case request.method_name
          when "none"
            handle_none(request)
          when "password"
            handle_password(request)
          when "publickey"
            handle_publickey(request)
          else
            Logger.warn(self, "Unknown auth method", method: request.method_name)
            :failure
          end

          case result
          when :success
            handle_successful_auth(request)
            true
          when :pk_ok
            Logger.debug(self, "Public key accepted", user: request.username)
            nil
          when :failure
            @attempts += 1

            packet = Protocol::UserauthFailure.new(authentications: SUPPORTED_METHODS)
            packet_stream.write(packet.serialize)

            Logger.debug(
              self,
              "Authentication failed",
              user: request.username,
              method: request.method_name,
              attempts: @attempts,
            )

            if @attempts >= config.max_auth_attempts
              Logger.warn(
                self,
                "Max auth attempts reached",
                user: request.username,
                attempts: @attempts,
              )
              @session.close
            end

            nil
          end
        end

        def handle_successful_auth(request)
          @authenticated_user = request.username
          packet_stream.write(Protocol::UserauthSuccess.new.serialize)
          handler.auth_succeeded(request.username)

          Logger.info(
            self,
            "Authentication successful",
            user: request.username,
            method: request.method_name,
          )
        end

        def verify_publickey_signature(request, pk_data)
          writer = Crussh::Transport::Writer.new
          writer.string(session_id)
          writer.byte(Protocol::USERAUTH_REQUEST)
          writer.string(request.username)
          writer.string(request.service_name)
          writer.string("publickey")
          writer.boolean(true)
          writer.string(pk_data.algorithm)
          writer.string(pk_data.key_blob)

          signed_data = writer.to_s

          handler.auth_publickey(
            request.username,
            pk_data.algorithm,
            pk_data.key_blob,
            pk_data.signature,
            signed_data,
          )
        end
      end
    end
  end
end
