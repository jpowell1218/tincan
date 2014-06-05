# A dummy used for sending a message.
class DummyClass
  attr_accessor :name

  def to_json(options)
    { name: name }.to_json(options)
  end
end
