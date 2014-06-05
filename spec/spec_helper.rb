require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

require 'rspec'
require 'pry'
require 'tincan'

Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].each do |file|
  require file
end

RSpec.configure do |config|
  config.order = 'random'
  config.include Futuristic::Matchers
end
