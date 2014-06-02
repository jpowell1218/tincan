require 'spec_helper'

describe Tincan::Sender do
  let(:sender) { Tincan::Sender.new(options) }
  let(:redis) { ::Redis.new(host: options[:redis_host]) }
  let(:fixture) { IO.read('spec/fixtures/message.json').strip }
  let(:message) { Tincan::Message.from_json(fixture) }
  let(:options) do
    {
      redis_host: 'localhost',
      redis_port: 6379,
      namespace: 'data'
    }
  end

  before { redis.flushdb }

  describe :lifecycle do
    it 'can be setup with a block' do
      instance = Tincan::Sender.new do |config|
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
        expect(sender.send(key)).to eq(options[key])
      end
    end
  end

  describe :related_objects do
    it 'memoizes a redis client' do
      expect(sender.redis_client).to be_a(Redis)
      expect(sender.redis_client.client.host).to eq(sender.redis_host)
      expect(sender.redis_client.client.port).to eq(sender.redis_port)
    end
  end

  describe :transactional_methods do
    describe :keys_for_receivers do
      before { redis.sadd('data:object:receivers', 'some_client') }

      it 'grabs receivers from Redis, maps them into message list keys' do
        result = sender.keys_for_receivers('object')
        expect(result).to eq(%w(data:object:some_client:messages))
      end
    end
  end

  describe :communication_methods do
    # These are very much "integration" tests as they test the main entry point
    # and the conditions of the sender from top to bottom.
    describe :publish do
      let(:dummy) do
        instance = Dummy.new
        instance.name = 'Some Idiot'
        instance
      end

      before do
        redis.sadd('data:dummy:receivers', 'some_client')
        sender.publish(dummy, :create)
        @timestamp = Time.now.to_i
      end

      it 'publishes a message to Redis at a specific key' do
        message = redis.get("data:dummy:messages:#{@timestamp}")
        expect(message).to be_a(String)
        expected = '{"object_name":"Dummy","change_type":"create",'
        expected += '"object_data":{"name":"Some Idiot"},"published_at":'
        expect(message).to start_with(expected)
      end

      it 'also publishes a message ID to client-specific receiver lists' do
        identifier = redis.lpop('data:dummy:some_client:messages')
        expect(identifier).to eq(@timestamp.to_s)
      end
    end
  end

  describe :formatting_helper_methods do
    describe :identifier_for_message do
      it 'generates a timestamp from the passed-in message' do
        expect(sender.identifier_for_message(message)).to eq(1401720216)
      end
    end

    describe :primary_key_for_message do
      it 'joins namespace, object name, and more to create a unique key' do
        expected = 'data:dummy:messages:1401720216'
        expect(sender.primary_key_for_message(message)).to eq(expected)
      end
    end
  end
end
