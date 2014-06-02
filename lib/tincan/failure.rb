require 'date'
require 'json'
require 'tincan/message'

module Tincan
  # Encapsulates a failed attempt at a message attempted from a Redis queue.
  class Failure
    attr_accessor :failed_at, :attempt_count, :message

    # Creates a new instance of a notification with an object (usually an
    # ActiveModel instance).
    # @param [Object] thing An object to encapsulate; usually an ActiveModel.
    # @param [Symbol] change_type :create, :modify, or :delete.
    # @return [Tincan::Message] An instance of this class.
    def initialize(message = nil)
      self.message = message
      self.attempt_count = 1
      self.failed_at = DateTime.now
    end

    # Gives a date and time when this object is allowed to be attempted again,
    # derived from when it last failed, plus the number of attempts, in
    # seconds.
    # @return [DateTime] The date/time when this is allowed to be retried.
    def attempt_after
      failed_at + Rational((attempt_count * 10), 86400)
    end

    # Deserializes an object from a JSON string.
    # @param [String] json A JSON string to be decoded.
    # @return [Tincan::Failure] A deserialized failure.
    def self.from_json(json)
      from_hash(JSON.parse(json))
    end

    # Assigns keys and values to this object based on an already-deserialized
    # JSON object.
    # @param [Hash] hash A hash of properties and their values.
    # @return [Tincan::Failure] A failure.
    def self.from_hash(hash)
      instance = new(Message.from_hash(hash['message']))
      instance.attempt_count = hash['attempt_count'].to_i + 1
      instance
    end

    # Generates a version of this failure as a JSON string.
    # @return [String] A JSON-compliant marshalling of this instance's data.
    def to_json(options = {})
      Hash[%i(failed_at attempt_count message).map do |name|
        [name, send(name)]
      end].to_json(options)
    end

    # Object overrides

    # Overrides equality operator to determine if all ivars are equal
    def ==(other)
      false unless other
      checks = %i(failed_at attempt_count message).map do |p|
        other.send(p) == send(p)
      end
      checks.all?
    end
  end
end
