# Workaround to make Rubygems believe it builds a native gem
require 'mkmf'
create_makefile('none')

if `uname -s`.chomp != 'Darwin'
  puts "Warning! Only Darwin (Mac OS X) systems are supported, nothing will be compiled"
else
  gem_root       = File.expand_path(File.join('..'))
  darwin_version = `uname -r`.to_i
  sdk_version    = { 9 => '10.5', 10 => '10.6', 11 => '10.7' }[darwin_version]

  raise "Only Darwin systems greater than 8 (Mac OS X 10.5+) are supported" unless sdk_version

  core_flags = %W{
    -isysroot /Developer/SDKs/MacOSX#{sdk_version}.sdk
    -mmacosx-version-min=#{sdk_version} -mdynamic-no-pic -std=gnu99
  }

  cflags = core_flags + %w{-Os -pipe}

  wflags = %w{
    -Wmissing-prototypes -Wreturn-type -Wmissing-braces -Wparentheses -Wswitch
    -Wunused-function -Wunused-label -Wunused-parameter -Wunused-variable
    -Wunused-value -Wuninitialized -Wunknown-pragmas -Wshadow
    -Wfour-char-constants -Wsign-compare -Wnewline-eof -Wconversion
    -Wshorten-64-to-32 -Wglobal-constructors -pedantic
  }

  ldflags = %w{
    -dead_strip -framework CoreServices
  }

  gcc_opts = core_flags + ldflags

  gcc_opts += %w{
    -D DEBUG=true
  } if ENV['FWDEBUG'] == "true"

  compile_command = "CFLAGS='#{cflags.join(' ')} #{wflags.join(' ')}' /usr/bin/gcc #{gcc_opts.join(' ')} -o '#{gem_root}/bin/fsevent_watch' fsevent/fsevent_watch.c"

  STDERR.puts(compile_command)

  # Compile the actual fsevent_watch binary
  system "mkdir -p #{File.join(gem_root, 'bin')}"
  system compile_command

  unless File.executable?("#{gem_root}/bin/fsevent_watch")
    raise "Compilation of fsevent_watch failed (see README)"
  end
end
