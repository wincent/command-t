# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

if !Object.const_defined?('Bundler')
  require 'rubygems'
  require 'bundler'
  Bundler.setup
end
require 'rspec'

lib = File.expand_path('../ruby', File.dirname(__FILE__))
unless $LOAD_PATH.include? lib
  $LOAD_PATH.unshift lib
end

RSpec.configure do |config|
  config.mock_framework = :rr
end

# Fake top-level VIM implementation, for stubbing.
module VIM
  class << self
    def evaluate(*args); end
  end

  class Buffer; end
end
