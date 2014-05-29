require 'tincans/message'

module Tincans
  # An object whose purpose is to listen to a variety of Redis queues and fire
  # off notifications when triggered.
  class Receiver
    # The configuration file loaded from YAML.
    attr_reader :config

    # Creates and return a listener object, ready to listen.
    def initialize(options = {})
      @config = YAML.load(IO.read(options[:config]))
    end

    # Registers this receiver against a Sidekiq queue. Returns self.
    def register
      channel_names.each do |channel|
        consumer_list_set_name = [channel, 'consumers'].join(':')
        redis_client.sadd(consumer_list_set_name, config['client_name'])
      end
      self
    end

    # Wraps this object's subscribe call with another block that forwards on
    # notifications to their proper methods.
    def listen
      register.subscribe do |object_name, message|
        method_signatures = config['channels'][object_name]
        method_signatures.each do |signature|
          class_name, method_name = signature.split('.')
          klass = class_name.constantize
          method_to_call = method_name.to_sym
          klass.send(method_to_call, message)
        end
      end
    end

    # Opens a communication channel to Redis and yields a given block when
    # triggered. Handles turning JSON back into notifications.
    def subscribe
      redis_client.subscribe(*channel_names) do |on|
        on.message do |channel, message_id|
          key = message_key(channel, message_id)
          json = redis_client.get(key)
          message = Tincans::Message.from_json(json)
          yield channel, message if block_given?
        end
      end
    end

    # A flattened list of channel names, in the format of
    # "model:client_name:messages".
    def channel_names
      @channel_names ||= config['channels'].keys.map do |model_name|
        [model_name, config['client_name'], 'messages'].join(':')
      end
    end

    # The instance of a Redis communicator that can subscribe messages.
    def redis_client
      @redis_client ||= Redis.new(host: config['redis_host'])
    end

    private

    def message_key(channel, message_id)
      [channel, 'messages', message_id].join(':')
    end
  end
end
