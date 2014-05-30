require 'simplecov'
SimpleCov.start do
  add_filter 'spec'
end

require 'rspec'
require 'pry'
require 'tincan'

Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].each do |file|
  require file
end

RSpec.configure do |config|
  config.order = 'random'
  config.include FuturisticMatchers
end
