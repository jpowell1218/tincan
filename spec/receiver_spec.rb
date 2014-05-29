require 'spec_helper'

describe Tincans::Receiver do
  describe :lifecycle do
    it 'can be setup with a block'
    it 'can be setup with an options hash'
    it 'memoizes a redis client'
  end

  describe :transactional_methods do
    describe :register do
      it 'registers itself as a consumer for supplied channels'
      it 'returns self'
    end

    describe :store_failed_message do
      it 'stores a message ID in a specialized failures list'
      it 'returns the message count'
    end
  end

  describe :loop_methods do
    describe :listen do
      it 'registers and subscribes and calls methods and DOES ALL THE THINGS'
      # MOAR TESTS FOR THIS ONE
    end
  end

  describe :formatting_helper_methods do
    describe :message_for_id do
      it 'retrieves a message from Redis based on an ID and object'
      it 'is in the form of a Tincans::Message object'
      it 'returns nil if the object was not found'
    end

    describe :channel_names do
      it 'converts the channels ivar into properly-formatted Redis keys'
    end
  end
end
