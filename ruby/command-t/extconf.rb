# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'mkmf'

def header(item)
  unless find_header(item)
    puts "couldn't find #{item} (required)"
    exit 1
  end
end

# mandatory headers
header('float.h')
header('ruby.h')
header('stdlib.h')
header('string.h')

# optional headers (for CommandT::Watchman::Utils)
if have_header('fcntl.h') &&
  have_header('sys/errno.h') &&
  have_header('sys/socket.h')
  RbConfig::MAKEFILE_CONFIG['DEFS'] += ' -DWATCHMAN_BUILD'

  have_header('ruby/st.h') # >= 1.9; sets HAVE_RUBY_ST_H
  have_header('st.h')      # 1.8; sets HAVE_ST_H
end

# optional
if RbConfig::CONFIG['THREAD_MODEL'] == 'pthread'
  have_library('pthread', 'pthread_create') # sets HAVE_PTHREAD_H if found
end

RbConfig::MAKEFILE_CONFIG['CC'] = ENV['CC'] if ENV['CC']

create_makefile('ext')
