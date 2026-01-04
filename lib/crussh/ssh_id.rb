# frozen_string_literal: true

module Crussh
  class SshId
    PROTO_VERSION = "2.0"

    def initialize(software_version, comments: nil)
      @software_version = software_version
      @comments = comments
    end

    class << self
      def parse(line)
        line = line.chomp
        raise ProtocolError, "Invalid SSH identification: #{line.inspect}" unless line.start_with?("SSH-")

        parts = line.split("-", 3)
        raise ProtocolError, "Invalid SSH identification" if parts.length < 3

        proto_version = parts[1]
        unless proto_version == "2.0" || proto_version.start_with?("2.")
          raise ProtocolError, "Unsupported SSH protocol version: #{proto_version}"
        end

        software_and_comments = parts[2]
        software_version, comments = software_and_comments.split(" ", 2)

        new(software_version, comments: comments)
      end
    end

    attr_reader :software_version, :comments

    def to_s
      base = "SSH-#{PROTO_VERSION}-#{@software_version}"
      base += " #{@comments}" if @comments
      base
    end

    def serialize
      "#{self}\r\n"
    end
  end
end
