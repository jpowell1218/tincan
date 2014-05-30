require 'spec_helper'

# For testing purposes.
class Dummy
  def to_json(_options)
    '{"key":"value"}'
  end
end

describe Tincans::Message do
  let(:message) { Tincans::Message.new(Dummy.new, :create) }
  let(:fixture) { IO.read('spec/fixtures/message.json').strip }

  describe :initialize do
    it 'takes an object and a change type symbol' do
      expect(message).to be_a(Tincans::Message)
    end

    it 'fails with an invalid symbol type' do
      process = -> { Tincans::Message.new(Dummy.new, :bork) }
      expect(process).to raise_error(ArgumentError)
    end

    it 'stores these as properties' do
      dummy = Dummy.new
      msg = Tincans::Message.new(dummy, :create)
      expect(msg.object_name).to eq('Dummy')
      expect(msg.change_type).to eq(:create)
      expect(msg.object_data).to eq(dummy)
      expect(msg.published_at).to be_a(DateTime)
    end
  end

  describe :to_json do
    it 'converts the message to a serialized JSON string' do
      expect(message.to_json).to be_a(String)
      expect { JSON.parse(message.to_json) }.to_not raise_error
    end

    it 'includes the proper data' do
      fixture.slice!('"2014-05-29 20:19:08 -0500"}')
      expect(message.to_json).to start_with(fixture)
    end
  end

  describe :from_json do
    let(:from_json) { Tincans::Message.from_json(fixture) }
    it 'deserializes an object from a JSON string' do
      expect(from_json).to be_a(Tincans::Message)
    end

    it 'sets everything up properly' do
      expect(from_json.object_name).to eq('Dummy')
      expect(from_json.change_type).to eq(:create)
      expect(from_json.object_data).to eq('key' => 'value')
      expect(from_json.published_at).to be_a(DateTime)
    end
  end
end
