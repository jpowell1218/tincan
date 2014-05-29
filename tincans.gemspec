# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tincans/version'

Gem::Specification.new do |spec|
  spec.name          = 'captainu-tincans'
  spec.version       = Tincans::VERSION
  spec.authors       = ['Ben Kreeger']
  spec.email         = %w(ben@captainu.com)
  spec.summary       = %q(A simple implementation of reliable Redis messaging.)
  spec.description   = <<-DESC
  Provides an easy way to register senders and receivers on a reliable Redis
  message queue.
  DESC

  spec.homepage      = 'https://github.com/captainu/tincans'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake'
end
