Dir[File.join(File.dirname(__FILE__), 'tincans', '*.rb')].each do |file|
  require file
end

# Provides an easy way to register senders and receivers on a reliable Redis
# message queue.
module Tincans
end
