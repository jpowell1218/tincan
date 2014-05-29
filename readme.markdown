# Tincans

Provides an easy way to register senders and receivers on a reliable Redis message queue. More infomation coming soon.

## Installation

Add this line to your application's Gemfile:

    gem 'captainu-tincans'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install captainu-tincans

## Usage

Coming soon.

## Example configuration

``` yaml
channels:
  college:
    - College.update_from_tincans
  college_team:
    - CollegeTeam.update_from_tincans
redis_host: localhost
client_name: teamlab
```

## Contributing

1. Fork it ( https://github.com/captainu/tincans/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
