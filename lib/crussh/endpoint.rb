# frozen_string_literal: true

module Crussh
  class Endpoint < IO::Endpoint::Generic
    def initialize(endpoint, **options)
      @endpoint = endpoint

      super(**options)
    end

    def bind(*arguments, &block)
      @endpoint.bind(*arguments, &block)
    end

    def connect(&block)
      @endpoint.connect(&block)
    end
  end
end
