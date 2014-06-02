require 'date'
require 'json'

module Tincan
  # Encapsulates a message published to (and received from) a Redis "tincan"
  # queue.
  class Message
    attr_accessor :object_name, :change_type, :object_data, :published_at

    # Creates a new instance of a notification with an object (usually an
    # ActiveModel instance).
    # @param [Object] thing An object to encapsulate; usually an ActiveModel.
    # @param [Symbol] change_type :create, :modify, or :delete.
    # @return [Tincan::Message] An instance of this class.
    def initialize(thing = nil, change_type = nil)
      if block_given?
        yield self
      else
        self.object_name = thing.class.name
        self.change_type = change_type
        self.object_data = thing
      end
      self.published_at ||= DateTime.now
    end

    # Deserializes an object from a JSON string.
    # @param [String] json A JSON string to be decoded.
    # @return [Tincan::Message] A deserialized notification.
    def self.from_json(json)
      from_hash(JSON.parse(json))
    end

    # Assigns keys and values to this object based on an already-deserialized
    # JSON object.
    # @param [Hash] hash A hash of properties and their values.
    # @return [Tincan::Message] A message.
    def self.from_hash(hash)
      instance = new do |i|
        hash.each do |key, val|
          if key == 'published_at'
            val = DateTime.iso8601(val)
          end
          i.send("#{key}=".to_sym, val)
        end
      end
      instance
    end

    # Checks for proper change type and sets it if it's valid.
    # @param [Symbol] value :create, :modify, or :delete.
    def change_type=(value)
      if %i(create modify delete).include?(value.to_sym)
        @change_type = value.to_sym
      else
        fail ArgumentError, ':change_type must be :create, :modify or :delete'
      end
    end

    # Generates a version of this notification as a JSON string.
    # @return [String] A JSON-compliant marshalling of this instance's data.
    def to_json(options = {})
      # Note: at some point I may want to override how this is done. I think
      # Rabl could definitely be of some use here.
      Hash[%i(object_name change_type object_data published_at).map do |name|
        [name, send(name)]
      end].to_json(options)
    end

    # Object overrides

    # Overrides equality operator to determine if all ivars are equal
    def ==(other)
      false unless other
      checks = %i(object_name change_type object_data published_at).map do |p|
        other.send(p) == send(p)
      end
      checks.all?
    end
  end
end
