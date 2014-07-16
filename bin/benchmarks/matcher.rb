#!/usr/bin/env ruby
#
# Copyright 2013-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

lib  = File.expand_path('../../ruby', File.dirname(__FILE__))
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'command-t/ext'
require 'command-t/util'
require 'benchmark'
require 'ostruct'
require 'yaml'

yaml    = File.expand_path('../../data/benchmark.yml', File.dirname(__FILE__))
data    = YAML.load_file(yaml)
threads = CommandT::Util.processor_count

puts "Starting benchmark run (PID: #{Process.pid})"

Benchmark.bmbm do |b|
  data['tests'].each do |test|
    scanner = OpenStruct.new(:paths => test['paths'])
    matcher = CommandT::Matcher.new(scanner)
    b.report(test['name']) do
      test['times'].times do
        test['queries'].each do |query|
          matcher.sorted_matches_for(query, :threads => threads)
        end
      end
    end
  end
end
