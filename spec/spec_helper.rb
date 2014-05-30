require 'tincan'
require 'rspec'
require 'pry'

Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].each do |file|
  require file
end

RSpec.configure do |config|
  config.order = 'random'
end
