require 'spec_helper'

describe Tincans::Receiver do
  let(:options) do
    {
      redis_host: 'localhost',
      client_name: 'bork',
      namespace: 'data',
      channels: {
        channel_one: ['ClassName.method_thing'],
        channel_two: ['OtherClass.another_method']
      },
      on_exception: ->(ex, _context) { puts ex }
    }
  end

  describe :lifecycle do
    it 'can be setup with a block' do
      receiver = Tincans::Receiver.new do |config|
        options.keys.each do |key|
          config.send("#{key}=", options[key])
        end
      end

      options.keys.each do |key|
        expect(receiver.send(key)).to eq(options[key])
      end
    end

    it 'can be setup with an options hash' do
      receiver = Tincans::Receiver.new(options)

      options.keys.each do |key|
        expect(receiver.send(key)).to eq(options[key])
      end
    end
  end

  describe :related_objects do
    it 'memoizes a redis client' do
      receiver = Tincans::Receiver.new(options)
      expect(receiver.redis_client).to be_a(Redis)
      # expect(receiver.redis_client.host).to eq('redis://localhost:6379/0')
    end
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
