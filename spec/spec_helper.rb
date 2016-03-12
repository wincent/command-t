# Copyright 2010-present Greg Hurrell. All rights reserved.
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

require 'command-t'
require 'command-t/ext'

RSpec.configure do |config|
  config.mock_framework = :rr
end

# Fake top-level VIM implementation, for stubbing.
module VIM
  class << self
    def evaluate(*args); end
  end

  Buffer = Class.new
end
