# frozen_string_literal: true

module Crussh
  class Server
    class AuthHandler
      include Auth::DSL

      def initialize(block)
        @block = block
      end

      def call(*args)
        result = instance_exec(*args, &@block)
        Auth.normalize(result)
      end
    end
  end
end
