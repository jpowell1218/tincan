require 'spec_helper'

describe Tincan::Receiver do
  let(:receiver) { Tincan::Receiver.new(options) }
  let(:redis) { ::Redis.new(host: options[:redis_host]) }
  let(:options) do
    {
      redis_host: 'localhost',
      redis_port: 6379,
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
      instance = Tincan::Receiver.new do |config|
        options.keys.each do |key|
          config.send("#{key}=", options[key])
        end
      end

      options.keys.each do |key|
        expect(instance.send(key)).to eq(options[key])
      end
    end

    it 'can be setup with an options hash' do
      options.keys.each do |key|
        expect(receiver.send(key)).to eq(options[key])
      end
    end
  end

  describe :related_objects do
    it 'memoizes a redis client' do
      expect(receiver.redis_client).to be_a(Redis)
      expect(receiver.redis_client.client.host).to eq(receiver.redis_host)
      expect(receiver.redis_client.client.port).to eq(receiver.redis_port)
    end
  end

  describe :transactional_methods do
    describe :register do
      it 'registers itself as a consumer for supplied channels' do
        receiver.register
        consumers = redis.smembers('data:channel_one:consumers')
        expect(consumers).to include(receiver.client_name)
      end

      it 'returns self' do
        expect(receiver.register).to eq(receiver)
      end
    end

    describe :store_failed_message do
      it 'stores a message ID in a specialized failures list' do
        receiver.store_failed_message('channel_one', '55')
        failures = redis.lrange('data:channel_one:failures', 0, -1)
        expect(failures).to include('55')
      end

      it 'returns the message count' do

      end
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
      it 'is in the form of a Tincan::Message object'
      it 'returns nil if the object was not found'
    end

    describe :channel_names do
      it 'converts the channels ivar into properly-formatted Redis keys'
    end
  end
end
