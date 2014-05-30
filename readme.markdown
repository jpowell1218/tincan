# Tincan

[![Build Status](https://travis-ci.org/captainu/tincan.svg?branch=master)](https://travis-ci.org/captainu/tincan)

Provides an easy way to register senders and receivers on a reliable Redis message queue. More infomation coming soon.

## Installation

Add this line to your application's Gemfile:

    gem 'captainu-Tincan'

And then execute:

    $ bundle install

## Usage

``` ruby
receiver = Tincan::Receiver.new do |config|
  config.redis_host = 'localhost'
  config.client_name = 'teamlab'
  config.namespace = 'data'
  config.channels = {
    college: ['College.update_from_tincan'],
    college_team: ['CollegeTeam.update_from_tincan']
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
