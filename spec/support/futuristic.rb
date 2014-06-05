require 'timeout'

# Provides matchers for expecting asynchronous results.
module Futuristic
  module Matchers
    class Matcher
      attr_accessor :expected

      def evenual_result
        Timeout.timeout(5.0) do
          value = nil
          while value.nil?
            sleep(0.1)
            value = yield
          end
          value
        end
      rescue TimeoutError
        nil
      end

      def supports_block_expectations?
        true
      end
    end

    class EventuallyEqual < Matcher
      attr_accessor :condition

      def initialize(expected, condition = :equality)
        @expected = expected
        @condition = condition
      end

      def matches?(block)
        case condition
        when :equality
          expected == evenual_result(&block)
        when :class_equality
          expected == evenual_result(&block).class
        end
      end

      def failure_message
        "The block should've eventually resulted in #{expected} but it did not."
      end

      def failure_message_when_negated
        "The block shouldn't have eventually resulted in #{expected} but it did."
      end
    end

    def eventually_equal(target)
      Futuristic::Matchers::EventuallyEqual.new(target, :equality)
    end

    def eventually_be_a(target)
      Futuristic::Matchers::EventuallyEqual.new(target, :class_equality)
    end
  end
end
