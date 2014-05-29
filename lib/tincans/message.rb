require 'json'

module Tincans
  # Encapsulates a message published to (and received from) a Redis pub/sub
  # queue.
  class Message
    attr_accessor :object_name, :change_type, :object_data, :published_at

    # Creates a new instance of a notification with an object (usually an
    # ActiveModel instance).
    # @param [Object] thing An object to encapsulate; usually an ActiveModel.
    # @param [Symbol] change_type :modify (for create/update) or :delete.
    # @return [Tincans::Message] An instance of this class.
    def initialize(thing, change_type)
      unless %i(modify delete).include?(change_type)
        fail ArgumentError, ':change_type must be :modify or :delete'
      end

      self.object_name = thing.class.name
      self.change_type = change_type
      self.object_data = thing
      self.published_at = Time.now
    end

    # Generates a version of this notification as a JSON string.
    # @return [String] A JSON-compliant marshalling of this instance's data.
    def to_json
      # Note: at some point I may want to override how this is done. I think
      # Rabl could definitely be of some use here.
      Hash[%i(object_name change_type object_data published_at).map do |name|
        [name, send(name)]
      end].to_json
    end

    # Deserializes an object from a JSON string.
    # @param [String] json A JSON string to be decoded.
    # @return [Pusher::Notification] A deserialized notification.
    def self.from_json(json)
      instance = new
      JSON.parse(json).each { |key, val| instance.send("#{key}=".to_sym, val) }
      instance
    end
  end
end
