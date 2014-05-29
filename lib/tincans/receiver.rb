require 'tincans/message'
require 'active_support/inflector'

module Tincans
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
        %w(client_name channels redis_host redis_port namespace).each do |n|
          send("@#{n}=", @config[n])
        end
      end
      self.redis_port ||= 6379
    end

    # The instance of a Redis communicator that can subscribe messages.
    def redis_client
      @redis_client ||= Redis.new(host: "redis://#{redis_host}:#{redis_port}")
    end

    # Transactional methods

    # Registers this receiver against a Sidekiq queue. Returns self.
    def register
      channel_names.each do |channel|
        consumer_list_key = key_for_elements(namespace, channel, 'consumers')
        redis_client.sadd(consumer_list_key, client_name)
      end
      self
    end

    # Handles putting a message identifier into a failed "retries" list.
    def store_failed_message(list, message_id)
      redis_client.rpush(list, message_id)
    end

    # Loop methods

    # Wraps this object's subscribe call with another block that forwards on
    # notifications to their proper methods.
    def listen
      register
      subscribe do |object_name, message|
        channels[object_name].each do |signature|
          class_name, method_name = signature.split('.')
          klass = Inflector.constantize(class_name)
          method_to_call = method_name.to_sym
          klass.send(method_to_call, message)
        end
      end
    end

    # Formatting and helper methods

    # Asks the instance of Redis for the proper JSON data for a message, and
    # then turns that into a Tincans::Message.
    def message_for_id(message_id, object_name)
      key = key_for_elements(object_name, 'messages', message_id)
      json = redis_client.get(key)
      return nil unless json
      Tincans::Message.from_json(json)
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
          object_name = list.split(':').first
          message = message_for_id(message_id, object_name)
          yield(object_name, message) if message && block_given?
        rescue Exception => e
          on_exception.call(e) if on_exception
          store_failed_message(list, message_id)
        end
      end
    end

    def key_for_elements(*elements)
      ([namespace] + elements).join(':')
    end
  end
end
