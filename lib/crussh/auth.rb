# frozen_string_literal: true

module Crussh
  module Auth
    Result = Data.define(:status, :continue_with) do
      class << self
        def success
          new(status: :success, continue_with: nil)
        end

        def failure
          new(status: :failure, continue_with: nil)
        end

        def partial(*methods)
          new(status: :parital, continue_with: methods)
        end
      end

      def success? = status == :success
      def partial? = status == :partial
      def failure? = status == :failure
    end

    class << self
      def accept = Result.success
      def reject = Result.failure
      def partial(...) = Result.partial(...)

      def normalize(result)
        case result
        when Result then result
        when true then accept
        when false, nil then reject
        else reject
        end
      end
    end

    module DSL
      def accept = Auth.accept
      def reject = Auth.reject
      def partial(...) = Auth.partial(...)
    end
  end
end
