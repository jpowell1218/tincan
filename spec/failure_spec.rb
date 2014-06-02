require 'spec_helper'

describe Tincan::Failure do
  let(:dummy) do
    instance = Dummy.new
    instance.name = 'Some Idiot'
    instance
  end

  let(:message_fixture) { IO.read('spec/fixtures/message.json').strip }
  let(:message) { Tincan::Message.from_json(message_fixture) }
  let(:failure) { Tincan::Failure.new(message) }
  let(:fixture) { IO.read('spec/fixtures/failure.json').strip }

  describe :initialize do
    it 'takes an message object, sets attempt count to 1' do
      expect(failure).to be_a(Tincan::Failure)
      expect(failure.attempt_count).to eq(1)
      expect(failure.failed_at).to be_a(DateTime)
    end
  end

  describe :attempt_after do
    it 'takes failed date/time and extends it by a number of seconds' do
      expect(failure.attempt_after).to eq(failure.failed_at + 10.0/86400.0)
    end

    it 'extends the next attempt based on attempt_count' do
      failure.attempt_count = 2
      expect(failure.attempt_after).to eq(failure.failed_at + 20.0/86400.0)
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
      expect(from_json.message.change_type).to eq(message.change_type)
      expect(from_json.message.object_data).to eq(message.object_data)
      expect(from_json.message.object_name).to eq(message.object_name)

      published_at_s = JSON.parse(fixture)['message']['published_at']
      published_at = DateTime.iso8601(published_at_s)
      expect(from_json.message.published_at).to eq(published_at)

      expect(from_json.attempt_count).to eq(2)
      expect(from_json.failed_at).to be_a(DateTime)
    end
  end
end
