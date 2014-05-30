require 'tincan/message'
require 'redis'

module Tincan
  # An object whose purpose is to send messages to a given series of Redis
  # message queues for those receiving them.
  class Sender
    attr_reader :config
    attr_accessor :redis_host, :redis_port, :namespace

    # Lifecycle methods

    # Creates and return a sender object, ready to send. You can pass in
    # either a hash or a block; the block takes priority.
    # @param [Hash] options A list of keys/values to assign to this instance.
    # @return [Tincan::Receiver] Self.
    def initialize(options = {})
      if block_given?
        yield(self)
      else
        @config = options
        ivars =  %i(redis_host redis_port namespace)
        ivars.each { |n| send("#{n}=".to_sym, @config[n]) }
      end
      self.redis_port ||= 6379
    end

    # Related objects

    # The instance of a Redis communicator that can publish messages.
    # @return [Redis] The Redis client used by this object.
    def redis_client
      @redis_client ||= ::Redis.new(host: redis_host, port: redis_port)
    end

    # Transactional (lookup) methods

    # Asks Redis for the set of all active receivers and generates string
    # keys for all of them. Formatted like "namespace:object:client:messages".
    # @return [Array] An array of keys identifying all receiver pointer lists.
    def keys_for_receivers(object_name)
      receiver_list_key = key_for_elements(object_name, 'receivers')
      receivers = redis_client.smembers(receiver_list_key)
      receivers.map do |receiver|
        key_for_elements(object_name, receiver, 'messages')
      end
    end

    # Communication methods

    # Bundles up an object in a message object and publishes it to the Redis
    # host.
    # @param [Object] object The object to bundle in a message.
    # @param [Symbol] change_type :create, :modify, or :delete.
    # @return [Boolean] true if the operation was a success.
    def publish(object, change_type)
      message = Message.new(object, change_type)
      identifier = identifier_for_message(message)
      redis_client.set(primary_key_for_message(message), message.to_json)
      keys_for_receivers(message.object_name.downcase).each do |key|
        redis_client.rpush(key, identifier)
      end
      true
    end

    # Formatting and helper methods

    # Generates an identifier to be used for a message. It's unique!
    # @param [Tincan::Message] message The message for which to generate a
    #                          unique identifier.
    # @return [Integer] A unique identifier number for the message.
    def identifier_for_message(message)
      message.published_at.to_time.to_i
    end

    # Generates a key to be used as the primary destination key in Redis.
    # @param [Tincan::Message] message The message to use in key generation.
    # @return [String] A properly-formatted key to be used with Redis.
    def primary_key_for_message(message)
      identifier = identifier_for_message(message)
      key_for_elements(message.object_name.downcase, 'messages', identifier)
    end

    private

    # Joins a variadic set of elements along with a namespace with colons.
    # @return [String] A joined string to be used as a Redis key.
    def key_for_elements(*elements)
      ([namespace] + elements).join(':')
    end
  end
end
