require 'tincan/message'
require 'active_support/inflector'
require 'redis'

module Tincan
  # An object whose purpose is to listen to a variety of Redis queues and fire
  # off notifications when triggered.
  class Receiver
    # The configuration file loaded from YAML.
    attr_reader :config
    attr_accessor :client_name, :channels, :redis_host, :redis_port, :namespace,
                  :on_exception

    # Lifecycle methods

    # Creates and return a listener object, ready to listen.
    def initialize(options = {})
      if block_given?
        yield(self)
      else
        @config = options
        ivars =  %i(client_name channels redis_host redis_port namespace
                    on_exception)
        ivars.each { |n| send("#{n}=".to_sym, @config[n]) }
      end
      self.redis_port ||= 6379
    end

    # Related objects

    # The instance of a Redis communicator that can subscribe messages.
    def redis_client
      @redis_client ||= ::Redis.new(host: redis_host, port: redis_port)
    end

    # Transactional methods

    # Registers this receiver against a Sidekiq queue. Returns self.
    def register
      channels.keys.each do |channel|
        consumer_list_key = key_for_elements(channel, 'consumers')
        redis_client.sadd(consumer_list_key, client_name)
      end
      self
    end

    # Handles putting a message identifier into a failed "retries" list.
    def store_failed_message(list, message_id)
      error_list = key_for_elements(list, 'failures')
      redis_client.rpush(error_list, message_id)
    end

    # Message handling methods

    # Iterates through stored lambdas for a given object, and passes the
    # message to all of them.
    def handle_message_for_object(object_name, message)
      channels[object_name.to_sym].each do |stored_lambda|
        stored_lambda.call(message)
      end
    end

    # Loop methods

    # Wraps this object's subscribe call with another block that forwards on
    # notifications to their proper methods.
    def listen
      register
      subscribe do |object_name, message|
        handle_message_for_object(object_name, message)
      end
    end

    # Formatting and helper methods

    # Asks the instance of Redis for the proper JSON data for a message, and
    # then turns that into a Tincan::Message.
    def message_for_id(message_id, object_name)
      key = key_for_elements(object_name, 'messages', message_id)
      json = redis_client.get(key)
      return nil unless json
      Message.from_json(json)
    end

    # A flattened list of channel names, in the format of
    # "model:client_name:messages".
    def channel_names
      @channel_names ||= channels.keys.map do |model_name|
        key_for_elements(model_name, client_name, 'messages')
      end
    end

    private

    # Opens a communication channel to Redis and yields a given block when
    # triggered. Handles turning JSON back into notifications. Uses BLPOP
    # command as a blocking pop, indefinitely, until we get a message.
    def subscribe
      loop do
        begin
          list, message_id = redis_client.blpop(channel_names)
          object_name = list.split(':')[1]
          message = message_for_id(message_id, object_name)
          yield(object_name, message) if message && block_given?
        rescue Exception => e
          on_exception.call(e, {}) if on_exception
          store_failed_message(list, message_id)
        end
      end
    end

    def key_for_elements(*elements)
      ([namespace] + elements).join(':')
    end
  end
end
