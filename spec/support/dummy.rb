# A dummy used for sending a message.
class Dummy
  attr_accessor :name

  def to_json(options)
    { name: name }.to_json(options)
  end
end
