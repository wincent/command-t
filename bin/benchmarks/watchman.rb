#!/usr/bin/env ruby
#
# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

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
