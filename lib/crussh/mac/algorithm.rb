# frozen_string_literal: true

module Crussh
  module Mac
    class Algorithm
      def initialize(key)
        @key = key
      end

      def key_length = 0
      def mac_length = 0
      def etm? = false

      def compute(sequence, data)
        raise NotImplementedError
      end

      def verify?(sequence, data, mac)
        true
      end
    end
  end
end
