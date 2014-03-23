#!/usr/bin/env ruby
#
# Copyright 2014 Wincent Colaiuta. All rights reserved.
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

lib  = File.expand_path('../../ruby', File.dirname(__FILE__))
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'command-t/ext'
require 'benchmark'
require 'json'
require 'pathname'
require 'socket'

puts "Starting benchmark run (PID: #{Process.pid})"

TEST_TIMES = 10

Benchmark.bmbm do |b|
  b.report('watchman JSON') do
    TEST_TIMES.times do
      sockname = JSON[%x{watchman get-sockname}]['sockname']
      raise unless $?.exitstatus.zero?
      UNIXSocket.open(sockname) do |s|
        root = Pathname.new(ENV['PWD']).realpath
        s.puts JSON.generate(['watch-list'])
        if !JSON[s.gets]['roots'].include?(root)
          # this path isn't being watched yet; try to set up watch
          s.puts JSON.generate(['watch', root])

          # root_restrict_files setting may prevent Watchman from working
          raise if JSON[s.gets].has_key?('error')
        end

        s.puts JSON.generate(['query', root, {
          'expression' => ['type', 'f'],
          'fields'     => ['name'],
        }])
        paths = JSON[s.gets]

        # could return error if watch is removed
        raise if paths.has_key?('error')
      end
    end
  end

  b.report('watchman binary') do
    TEST_TIMES.times do
      sockname = CommandT::Watchman::Utils.load(
        %x{watchman --output-encoding=bser get-sockname}
      )['sockname']
      raise unless $?.exitstatus.zero?

      UNIXSocket.open(sockname) do |socket|
        root = Pathname.new(ENV['PWD']).realpath.to_s
        roots = CommandT::Watchman::Utils.query(['watch-list'], socket)['roots']
        if !roots.include?(root)
          # this path isn't being watched yet; try to set up watch
          result = CommandT::Watchman::Utils.query(['watch', root], socket)

          # root_restrict_files setting may prevent Watchman from working
          raise if result.has_key?('error')
        end

        query = ['query', root, {
          'expression' => ['type', 'f'],
          'fields'     => ['name'],
        }]
        paths = CommandT::Watchman::Utils.query(query, socket)

        # could return error if watch is removed
        raise if paths.has_key?('error')
      end
    end
  end
end
