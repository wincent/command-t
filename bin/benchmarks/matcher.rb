#!/usr/bin/env ruby
#
# Copyright 2013-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require_relative 'base.rb'

require 'ostruct'
require 'yaml'


class MatcherBenchmark < CommandT::Benchmark
  def initialize
    @data = YAML.load_file(
      File.expand_path('../../data/benchmark.yml', File.dirname(__FILE__))
    )
    @threads = CommandT::Util.processor_count
  end

  def exec b
    @data['tests'].each do |test|
      scanner = OpenStruct.new(:c_paths => CommandT::Paths.from_array(test['paths']))
      matcher = CommandT::Matcher.new(scanner)
      b.report(test['name']) do
        test['times'].times do
          test['queries'].each do |query|
            query.split(//).reduce('') do |acc, char|
              query = acc + char

              matcher.sorted_matches_for query,
                threads: @threads,
                recurse: ENV.fetch('RECURSE', '1') == '1',
                limit: ENV.fetch('LIMIT', '200').to_i

              query
            end
          end
        end
      end
    end
  end
end

MatcherBenchmark.new.run
