require 'Tincan'
require 'rspec'
require 'pry'
require 'vcr'
require 'fakeredis/rspec'

Dir[File.join(File.dirname(__FILE__), 'support', '**', '*.rb')].each do |file|
  require file
end

VCR.configure do |c|
  c.cassette_library_dir = 'spec/cassettes'
  c.hook_into(:webmock)
  c.configure_rspec_metadata!
  c.default_cassette_options = { record: :new_episodes }
end

RSpec.configure do |config|
  config.order = 'random'
  # config.extend VCR::RSpec::Macros
  config.treat_symbols_as_metadata_keys_with_true_values = true
end
