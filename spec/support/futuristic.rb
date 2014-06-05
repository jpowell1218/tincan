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
      def initialize(expected)
        @expected = expected
      end

      def matches?(block)
        expected == evenual_result(&block)
      end

      def failure_message
        "The block should've eventually resulted in #{expected} but it did not."
      end

      def failure_message_when_negated
        "The block shouldn't have eventually resulted in #{expected} but it did."
      end
    end

    def eventually_equal(target)
      Futuristic::Matchers::EventuallyEqual.new(target)
    end
  end
end
