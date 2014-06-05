require 'spec_helper'

describe Tincan::Failure do
  let(:dummy) do
    instance = DummyClass.new
    instance.name = 'Some Idiot'
    instance
  end

  # let(:message_fixture) { IO.read('spec/fixtures/message.json').strip }
  # let(:message) { Tincan::Message.from_json(message_fixture) }
  let(:failure) { Tincan::Failure.new(100, 'some_queue') }
  let(:fixture) { IO.read('spec/fixtures/failure.json').strip }

  describe :initialize do
    it 'takes an message object, sets attempt count to 0' do
      expect(failure).to be_a(Tincan::Failure)
      expect(failure.attempt_count).to eq(0)
      expect(failure.failed_at).to be_a(DateTime)
    end
  end

  describe :attempt_after do
    it 'takes failed date/time and extends it by a number of seconds' do
      failure.attempt_count = 1
      expected = Rational(10, 86400)
      expect(failure.attempt_after).to eq(failure.failed_at + expected)
    end

    it 'extends the next attempt based on attempt_count' do
      failure.attempt_count = 2
      expected = Rational(20, 86400)
      expect(failure.attempt_after).to eq(failure.failed_at + expected)
    end
  end

  describe :to_json do
    it 'converts the failure to a serialized JSON string' do
      expect(failure.to_json).to be_a(String)
      expect { JSON.parse(failure.to_json) }.to_not raise_error
    end
  end

  describe :from_json do
    let(:from_json) { Tincan::Failure.from_json(fixture) }

    it 'deserializes an object from a JSON string' do
      expect(from_json).to be_a(Tincan::Failure)
    end

    it 'sets everything up properly' do
      expect(from_json.message_id).to eq('55')
      expect(from_json.attempt_count).to eq(1)
      expect(from_json.failed_at).to be_a(DateTime)
      expect(from_json.queue_name).to eq('data:object_one:client:messages')
    end
  end
end
