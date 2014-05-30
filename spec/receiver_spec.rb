require 'spec_helper'

# A test helper for handling messages.
class Handler
  attr_accessor :data
end

describe Tincan::Receiver do
  let(:fixture) { IO.read('spec/fixtures/message.json').strip }
  let(:receiver) { Tincan::Receiver.new(options) }
  let(:redis) { ::Redis.new(host: options[:redis_host]) }
  let(:handler_one_alpha) { Handler.new }
  let(:handler_one_beta) { Handler.new }
  let(:handler_two_alpha) { Handler.new }
  let(:options) do
    {
      redis_host: 'localhost',
      redis_port: 6379,
      client_name: 'bork',
      namespace: 'data',
      channels: {
        channel_one: [
          -> (data) { handler_one_alpha.data = data },
          -> (data) { handler_one_beta.data = data }
          ],
        channel_two: [-> (data) { handler_two_alpha.data = data }]
      },
      on_exception: ->(ex, _context) { puts "Exception: #{ex}" }
    }
  end

  before { redis.flushdb }

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

      it 'returns the message count in the failures queue' do
        result = receiver.store_failed_message('channel_one', '55')
        expect(result).to eq(1)
        result = receiver.store_failed_message('channel_one', '56')
        expect(result).to eq(2)
      end
    end
  end

  describe :message_handling_methods do
    describe :handle_message_for_object do
      it 'iterates through the channel dict and calls lambdas' do
        receiver.handle_message_for_object('channel_one', 'hello world')
        receiver.handle_message_for_object('channel_two', 'goodbye world')

        expect(handler_one_alpha.data).to eq('hello world')
        expect(handler_one_beta.data).to eq('hello world')
        expect(handler_two_alpha.data).to eq('goodbye world')
      end
    end
  end

  describe :loop_methods do
    # These are very much "integration" tests as they test the main entry point
    # and the conditions of the receiver from top to bottom.
    describe :listen do
      it 'registers, subscribes, calls methods, and DOES ALL THE THINGS' do
        thread = Thread.new { receiver.listen }

        get_consumers = -> { redis.smembers('data:channel_one:consumers') }
        expect(get_consumers).to eventually_eq(%w(bork))

        redis.set('data:channel_one:messages:1', fixture)
        consumers = redis.smembers('data:channel_one:consumers')
        consumers.each do |consumer|
          redis.rpush("data:channel_one:#{consumer}:messages", '1')
        end

        message = Tincan::Message.from_json(fixture)
        expect { handler_one_alpha.data }.to eventually_eq(message)
        expect { handler_one_beta.data }.to eventually_eq(message)

        thread.kill
      end
    end
  end

  describe :formatting_helper_methods do
    let(:result) { receiver.message_for_id(1, 'bobsyouruncle') }
    let(:message) { Tincan::Message.from_json(fixture) }
    before do
      redis.set('data:bobsyouruncle:messages:1', fixture)
    end

    describe :message_for_id do
      it 'retrieves a message from Redis based on an ID and object' do
        expect(result).to eq(message)
      end

      it 'is in the form of a Tincan::Message object' do
        expect(result).to be_a(Tincan::Message)
      end

      it 'returns nil if the object was not found' do

      end
    end

    describe :channel_names do
      it 'converts the channels ivar into properly-formatted Redis keys'
    end
  end
end
