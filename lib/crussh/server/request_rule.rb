# frozen_string_literal: true

module Crussh
  class Server
    class RequestRule
      class << self
        def accept(only: nil, except: nil, if: nil, unless: nil, &block)
          new(
            allow: true,
            only: only,
            except: except,
            if: binding.local_variable_get(:if),
            unless: binding.local_variable_get(:unless),
            &block
          )
        end

        def reject
          new(allow: false, only: nil, except: nil, if: nil, unless: nil, &block)
        end
      end

      def initialize(allow: true, only: nil, except: nil, if: nil, unless: nil, &block)
        @allow = allow
        @only = only
        @except = except
        @if = binding.local_variable_get(:if)
        @unless = binding.local_variable_get(:unless)
        @block = block
      end

      attr_reader :allow, :only, :except, :if, :unless, :block

      def allowed?(channel, **params)
        return false unless allow

        if only
          value = params[:name] || params[:term]
          return false unless matches_patterns?(only, value)
        end

        if except
          value = params[:name] || params[:term]
          return false if matches_patterns?(except, value)
        end

        return false if self.if && !self.if.call(channel, **params)
        return false if self.unless&.call(channel, **params)
        return block.call(channel, **params) if block

        true
      end

      private

      def matches_patterns?(patterns, value)
        return true if value.nil?

        Array(patterns).any? do |pattern|
          case pattern
          when Regexp
            pattern.match?(value)
          when String
            if pattern.include?("*")
              File.fnmatch?(pattern, value)
            else
              pattern == value
            end
          else
            pattern == value
          end
        end
      end
    end
  end
end
