#!/bin/sh -e
cd ruby/command-t
for RUBY_VERSION in $(ls ~/.multiruby/install); do
  echo "$RUBY_VERSION: building"
  export PATH=~/.multiruby/install/$RUBY_VERSION/bin:$PATH
  ruby extconf.rb
  make clean
  make
  echo "$RUBY_VERSION: finished"
done
