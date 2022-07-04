# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

if !Object.const_defined?('Bundler')
  require 'rubygems'
  require 'bundler'
  Bundler.setup
end
require 'rspec'

ext = File.expand_path('../ruby/command-t/lib', File.dirname(__FILE__))
lib = File.expand_path('../ruby/command-t/ext', File.dirname(__FILE__))
$LOAD_PATH.unshift(ext) unless $LOAD_PATH.include?(ext)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'command-t'
require 'command-t/ext'

# Fake top-level VIM implementation, for stubbing.
module VIM
  class << self
    def evaluate(*args); end
  end

  Buffer = Class.new
end
