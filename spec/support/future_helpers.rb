require 'timeout'

RSpec::Matchers.define :eventually_eq do |expected|
  match do |block|
    begin
      Timeout.timeout(2.0) do
        value = nil
        while value.nil?
          sleep(0.1)
          value = block.call
        end
        expected == value
      end
    rescue TimeoutError
      false
    end
  end
end
