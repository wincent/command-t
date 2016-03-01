#!/usr/bin/env ruby
#
# Copyright 2013-present Greg Hurrell. All rights reserved.
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

# Run the benchmarks 10 times so that we can report some variance numbers too.
results = 10.times.map do
  Benchmark.bmbm do |b|
    data['tests'].each do |test|
      scanner = OpenStruct.new(:paths => test['paths'])
      matcher = CommandT::Matcher.new(scanner)
      b.report(test['name']) do
        test['times'].times do
          test['queries'].each do |query|
            query.split(//).reduce('') do |acc, char|
              query = acc + char
              matcher.sorted_matches_for(
                query,
                :threads => threads,
                :recurse => ENV.fetch('RECURSE', '1') == '1'
              )
              query
            end
          end
        end
      end
    end
  end
end

# https://en.wikipedia.org/wiki/Winsorising
def winsor(items)
  length = items.length
  return items if length < 5
  items = items.sort
  [items[1]] + items[1..length - 2] + [items[length - 2]]
end

results = results.reduce({}) do |acc, run|
  run.each do |result|
    acc[result.label] ||= {}
    acc[result.label]['real'] ||= []
    acc[result.label]['real'] << result.real
    acc[result.label]['total'] ||= []
    acc[result.label]['total'] << result.total
  end
  acc
end

results.keys.each do |label|
  test = results[label]

  test['real (best)'] = test['real'].min
  test['total (best)'] = test['total'].min

  test['real'] = winsor(test['real'])
  test['total'] = winsor(test['total'])

  test['real (avg)'] = test['real'].reduce(:+) / test['real'].length
  test['total (avg)'] = test['total'].reduce(:+) / test['total'].length

  test['real (variance)'] = test['real'].reduce(0) { |acc, value|
    acc + (test['real (avg)'] - value) ** 2
  } / test['real'].length
  test['total (variance)'] = test['total'].reduce(0) { |acc, value|
    acc + (test['total (avg)'] - value) ** 2
  } / test['total'].length

  test['real (sd)'] = Math.sqrt(test['real (variance)'])
  test['total (sd)'] = Math.sqrt(test['total (variance)'])

  test.delete('real')
  test.delete('total')
end

puts "\n\nSummary:                                cpu time             (wall-clock time)\n"
width = results.keys.map(&:length).max
print ' ' * (width + 2)
print '%9s ' % 'avg'
print '%9s ' % 'best'
print '%9s ' % 'sd'
print '%9s ' % '(avg)'
print '%9s ' % '(best)'
print '%9s ' % '(sd)'
puts
results.each do |label, data|
  print "%#{width}s " % label
  print '   %.5f' % data['total (avg)']
  print '   %.5f' % data['total (best)']
  print '   %.5f' % data['total (sd)']
  print ' (%.5f)' % data['real (avg)']
  print ' (%.5f)' % data['real (best)']
  print ' (%.5f)' % data['real (sd)']
  puts
end
