require 'tincan/message'
require 'redis'

module Tincan
  # An object whose purpose is to listen to a variety of Redis queues and fire
  # off notifications when triggered.
  class Receiver
    attr_reader :config
    attr_accessor :client_name, :listen_to, :redis_host, :redis_port,
                  :namespace, :on_exception

    # Lifecycle methods

    # Creates and return a listener object, ready to listen. You can pass in
    # either a hash or a block; the block takes priority.
    # @param [Hash] options A list of keys/values to assign to this instance.
    # @return [Tincan::Receiver] Self.
    def initialize(options = {})
      if block_given?
        yield(self)
      else
        @config = options
        ivars =  %i(client_name listen_to redis_host redis_port namespace
                    on_exception)
        ivars.each { |n| send("#{n}=".to_sym, @config[n]) }
      end
      self.redis_port ||= 6379
    end

    # Related objects

    # The instance of a Redis communicator that can subscribe messages.
    # @return [Redis] The Redis client used by this object.
    def redis_client
      @redis_client ||= ::Redis.new(host: redis_host, port: redis_port)
    end

    # Transactional (submission) methods

    # Registers this receiver against a Redis set based on the object name.
    # Looks like "namespace:object_name:receivers".
    # @return [Tincan::Receiver] Self.
    def register
      listen_to.keys.each do |object_name|
        receiver_list_key = key_for_elements(object_name, 'receivers')
        puts receiver_list_key
        redis_client.sadd(receiver_list_key, client_name)
      end
      self
    end

    # Handles putting a message identifier into a failed "retries" list.
    # @param [String] original_list The name of the originating list.
    # @param [Integer] message_id The identifier of the failed message.
    # @return [Integer] The number of failed entries in the same list.
    def store_failed_message(original_list, message_id)
      error_list = key_for_elements(original_list, 'failures')
      redis_client.rpush(error_list, message_id)
    end

    # Message handling methods

    # Iterates through stored lambdas for a given object, and passes the
    # message to all of them.
    # @param [String] object_name The object name gleamed from the list key.
    # @param [Tincan::Message] message The Message generated from the JSON
    #                          hash retrieved from Redis.
    def handle_message_for_object(object_name, message)
      listen_to[object_name.to_sym].each do |stored_lambda|
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
    # @param [Integer] message_id The numerical ID of the message to retrieve.
    # @param [String] object_name The object name of the message to retrieve;
    #                 this helps the receiver determine which list it was
    #                 posted to.
    # @return [Tincan::Message] An initialized Message, or nil if not found.
    def message_for_id(message_id, object_name)
      key = key_for_elements(object_name, 'messages', message_id)
      json = redis_client.get(key)
      return nil unless json
      Message.from_json(json)
    end

    # A flattened list of message list keys, in the format of
    # "namespace:object_name:client:messages".
    # @return [Array] An array of object_names formatted with client name, like
    #                 "namespace:object_name:client:messages".
    def message_list_keys
      @message_list_keys ||= listen_to.keys.map do |object_name|
        key_for_elements(object_name, client_name, 'messages')
      end
    end

    private

    # Loops on a blocking pop call to a series of message lists on Redis and
    # yields a given block when triggered. Handles turning JSON back into
    # notification messages. Uses `BLPOP` as a blocking pop, indefinitely,
    # until we get a message.
    def subscribe
      loop do
        begin
          message_list, message_id = redis_client.blpop(message_list_keys)
          object_name = message_list.split(':')[1]
          message = message_for_id(message_id, object_name)
          yield(object_name, message) if message && block_given?
        rescue Exception => e
          on_exception.call(e, {}) if on_exception
          store_failed_message(message_list, message_id)
        end
      end
    end

    # Joins a variadic set of elements along with a namespace with colons.
    # @return [String] A joined string to be used as a Redis key.
    def key_for_elements(*elements)
      ([namespace] + elements).join(':')
    end
  end
end
