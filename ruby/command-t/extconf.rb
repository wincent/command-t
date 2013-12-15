# Copyright 2010-2013 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'mkmf'

def header(item)
  unless find_header(item)
    puts "couldn't find #{item} (required)"
    exit 1
  end
end

# Stolen, with minor modifications, from:
#
#   https://github.com/grosser/parallel/blob/d11e4a3c8c1a2091a0cc2896befa71a94a88d1e7/lib/parallel.rb
#
# Number of processors seen by the OS and used for process scheduling.
#
# * AIX: /usr/sbin/pmcycles (AIX 5+), /usr/sbin/lsdev
# * BSD: /sbin/sysctl
# * Cygwin: /proc/cpuinfo
# * Darwin: /usr/bin/hwprefs, /usr/sbin/sysctl
# * HP-UX: /usr/sbin/ioscan
# * IRIX: /usr/sbin/sysconf
# * Linux: /proc/cpuinfo
# * Minix 3+: /proc/cpuinfo
# * Solaris: /usr/sbin/psrinfo
# * Tru64 UNIX: /usr/sbin/psrinfo
# * UnixWare: /usr/sbin/psrinfo
#
def processor_count
  os_name = RbConfig::CONFIG['target_os']
  if os_name =~ /mingw|mswin/
    require 'win32ole'
    result = WIN32OLE.connect('winmgmts://').ExecQuery(
        'select NumberOfLogicalProcessors from Win32_Processor')
    result.to_enum.collect(&:NumberOfLogicalProcessors).reduce(:+)
  elsif File.readable?('/proc/cpuinfo')
    IO.read('/proc/cpuinfo').scan(/^processor/).size
  elsif File.executable?('/usr/bin/hwprefs')
    IO.popen(%w[/usr/bin/hwprefs thread_count]).read.to_i
  elsif File.executable?('/usr/sbin/psrinfo')
    IO.popen('/usr/sbin/psrinfo').read.scan(/^.*on-*line/).size
  elsif File.executable?('/usr/sbin/ioscan')
    IO.popen(%w[/usr/sbin/ioscan -kC processor]) do |out|
      out.read.scan(/^.*processor/).size
    end
  elsif File.executable?('/usr/sbin/pmcycles')
    IO.popen(%w[/usr/sbin/pmcycles -m]).read.count("\n")
  elsif File.executable?('/usr/sbin/lsdev')
    IO.popen(%w[/usr/sbin/lsdev -Cc processor -S 1]).read.count("\n")
  elsif File.executable?('/usr/sbin/sysconf') and os_name =~ /irix/i
    IO.popen(%w[/usr/sbin/sysconf NPROC_ONLN]).read.to_i
  elsif File.executable?('/usr/sbin/sysctl')
    IO.popen(%w[/usr/sbin/sysctl -n hw.ncpu]).read.to_i
  elsif File.executable?('/sbin/sysctl')
    IO.popen(%w[/sbin/sysctl -n hw.ncpu]).read.to_i
  else
    puts 'Unknown platform: ' + RbConfig::CONFIG['target_os']
    puts 'Assuming 1 processor.'
    1
  end
rescue => e
  puts "#{e}: assuming 1 processor."
  1
end

# mandatory headers
header('float.h')
header('ruby.h')
header('stdlib.h')
header('string.h')

# optional headers
have_header('pthread.h') # sets HAVE_PTHREAD_H if found

RbConfig::MAKEFILE_CONFIG['CC'] = ENV['CC'] if ENV['CC']

count = processor_count
count = 1 if count < 0   # sanity check
count = 32 if count > 32 # sanity check
RbConfig::MAKEFILE_CONFIG['DEFS'] += "-DPROCESSOR_COUNT=#{count}"

create_makefile('ext')
