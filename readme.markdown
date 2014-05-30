# Tincan

[![Build Status](https://travis-ci.org/captainu/tincan.svg?branch=master)](https://travis-ci.org/captainu/tincan) [![Code Climate](https://codeclimate.com/github/captainu/tincan.png)](https://codeclimate.com/github/captainu/tincan) [![Code Climate](https://codeclimate.com/github/captainu/tincan/coverage.png)](https://codeclimate.com/github/captainu/tincan) 

Provides an easy way to register senders and receivers on a reliable Redis message queue, to be used in lieu of Redis's own pub/sub commands (which are connection-reliant). This uses Redis's lists and sets using a defined and namespaced series of keys that allows for a *sender* to publish structured notification messages to a Redis server, which then get referenced in multiple receiver-specific lists, all of which are being watched by a client running a blocking pop (Redis's `BLPOP` command). These clients, known as *receivers*, handle the messages and route them to any number of custom-defined Ruby lambdas.
This is a Ruby implementation of [David Marquis's outstanding post](http://davidmarquis.wordpress.com/2013/01/03/reliable-delivery-message-queues-with-redis/) about reliable delivery message queues with Redis.

See below for some usage examples (more coming soon).

## Installation

Add this line to your application's Gemfile:

    gem 'captainu-tincan'

And then execute:

    $ bundle install

## Usage

### Sender

``` ruby
sender = Tincan::Sender.new do |config|
  config.redis_host = 'localhost'
  config.namespace = 'data'
end

# some_object here is something that responds to #to_json
sender.publish(some_object, :create)
```

### Receiver

``` ruby
receiver = Tincan::Receiver.new do |config|
  config.redis_host = 'localhost'
  config.client_name = 'teamlab'
  config.namespace = 'data'
  config.listen_to = {
    college: [
      ->(data) { SomeThing.handle_data(data) },
      ->(data) { SomeOtherThing.handle_same_data(data) }
    ],
    college_team: [
      -> (data) { AnotherThing.handle_this_data(data) }
    ]
  }
  config.on_exception = lambda do |ex, context|
    Airbrake.notify_or_ignore(ex, parameters: context)
  end
end

# This call blocks and loops
receiver.listen
```

## Contributing

1. [Fork it](https://github.com/captainu/tincan/fork)!
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new pull request

## Contributors

- [Ben Kreeger](https://github.com/kreeger)
