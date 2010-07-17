#!/bin/sh -e

function build_quietly()
{
  cd ruby/command-t
  ruby extconf.rb > /dev/null
  make clean > /dev/null
  make > /dev/null
  cd -
}

OLD_PATH=$PATH
for RUBY_VERSION in $(ls ~/.multiruby/install); do
  echo "$RUBY_VERSION: building"
  export PATH=~/.multiruby/install/$RUBY_VERSION/bin:$OLD_PATH
  build_quietly
  echo "$RUBY_VERSION: running spec suite"
  bin/rspec spec
  echo "$RUBY_VERSION: finished"
done

# put things back the way we found them
export PATH=$OLD_PATH
echo "Restoring: $(ruby -v)"
build_quietly
