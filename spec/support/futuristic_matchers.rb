require 'timeout'

# Provides matchers for expecting asynchronous results.
module FuturisticMatchers
  extend RSpec::Matchers::DSL

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

  matcher :eventually_equal do |expected|
    match { |block| expected == evenual_result(&block) }
  end

  matcher :eventually_be_a do |expected|
    match { |block| evenual_result(&block).is_a?(expected) }
  end

  matcher :eventually_be_nil do
    match { |block| evenual_result(&block).nil? }
  end

  matcher :eventually_be_true do
    match { |block| evenual_result(&block) == true }
  end
end
