require 'mkmf'

def missing item
  puts "couldn't find #{item} (required)"
  exit 1
end

have_header('ruby.h') or missing('ruby.h')
create_makefile('ext')
