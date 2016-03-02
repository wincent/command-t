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

data = YAML.load_file(
  File.expand_path('../../data/benchmark.yml', File.dirname(__FILE__))
)
log = File.expand_path('../../data/log.yml', File.dirname(__FILE__))
log_data = File.exist?(log) ? YAML.load_file(log) : []

threads = CommandT::Util.processor_count

puts "Starting benchmark run (PID: #{Process.pid})"
now = Time.now.to_s

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

DIFFERENCE = 0
ABSOLUTE = 1
SIGN = 2

# Test for significance via Wilcoxon Signed Rank test.
#
# @see http://vassarstats.net/textbook/ch12a.html
def significant?(last, current)
  table = last.zip(current).map do |l, c|
    [
      l - c, # difference
      (l - c).abs, # absolute difference
      (l - c).zero? ? nil : (l - c) / (l - c).abs, # signedness (-1 or +1)
    ]
  end
  table = table.select { |diff, abs, sig| !diff.zero? }
  table = table.sort do |(a_diff, a_abs, a_sig), (b_diff, b_abs, b_sig)|
    a_abs <=> b_abs
  end

  rank = 1
  table = table.map.with_index do |row, i|
    count = 0
    rank = table.map.with_index do |(diff, abs, sig), i|
      if abs == row[ABSOLUTE]
        count += 1
        i + 1
      else
        nil
      end
    end.compact.reduce(0) { |acc, val| acc + val } / count
    row + [row[SIGN] * rank]
  end

  n = table.length
  w = table.reduce(0) { |acc, (diff, abs, signed_rank)| acc + signed_rank }

  if n < 10
    significance = 0
    thresholds = [
      [],
      [],
      [],
      [],
      [],
      [[15, 0.05]],
      [[17, 0.05], [21, 0.025]],
      [[22, 0.05], [25, 0.025], [28, 0.01]],
      [[26, 0.05], [30, 0.025], [34, 0.01], [36, 0.005]],
      [[29, 0.05], [35, 0.025], [39, 0.01], [43, 0.005]],
    ][n]
    while limit = thresholds.pop do
      if w > limit[0]
        significance = limit[1]
        break
      end
    end
  else
    sd = Math.sqrt(n * (n + 1) *  (2 * n + 1) / 6)
    z = ((w - 0.5) / sd).abs
    if z > 3.291
      significance = 0.0005
    elsif z > 2.576
      significance = 0.005
    elsif z > 2.326
      significance = 0.01
    elsif z > 1.960
      significance = 0.025
    elsif z > 1.645
      significance = 0.05
    else
      significance = 0
    end
  end

  significance > 0
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

previous = YAML.load_file(log).last['results'] rescue nil

results.keys.each do |label|
  test = results[label]

  test['real (best)'] = test['real'].min
  test['total (best)'] = test['total'].min

  test['real (avg)'] = test['real'].reduce(:+) / test['real'].length
  test['real (+/-)'] = previous &&
    test['real (avg)'] / (test['real (avg)'] - previous[label]['real (avg)']) * 100
  test['real (significant?)'] = significant?(previous[label]['real'], test['real']) if previous
  test['total (avg)'] = test['total'].reduce(:+) / test['total'].length
  test['total (+/-)'] = previous &&
    test['total (avg)'] / (test['total (avg)'] - previous[label]['total (avg)']) * 100
  test['total (significant?)'] = significant?(previous[label]['total'], test['total']) if previous

  test['real (variance)'] = test['real'].reduce(0) { |acc, value|
    acc + (test['real (avg)'] - value) ** 2
  } / test['real'].length
  test['total (variance)'] = test['total'].reduce(0) { |acc, value|
    acc + (test['total (avg)'] - value) ** 2
  } / test['total'].length

  test['real (sd)'] = Math.sqrt(test['real (variance)'])
  test['total (sd)'] = Math.sqrt(test['total (variance)'])
end

log_data.push({
  'time' => now,
  'results' => results,
})
File.open(log, 'w') { |f| f.write(log_data.to_yaml) }

puts '-' * 94
puts "\n\nSummary:             cpu time                             (wall-clock time)\n"
width = results.keys.map(&:length).max
print ' ' * (width + 2)
print ' %8s ' % 'avg'
print '  %3s    ' % '+/-'
print ' %8s ' % 'best'
print ' %8s ' % 'sd'
print ' %8s ' % '(avg)'
print '  %3s    ' % '+/-'
print ' %8s ' % '(best)'
print ' %8s ' % '(sd)'
puts

results.each do |label, data|
  print "%#{width}s " % label
  print '   %.5f' % data['total (avg)']
  print data['total (+/-)'] ? ' [%+0.1f%%]' % data['total (+/-)'] : ' [-----]'
  print data['total (significant?)'] ? '*' : ' '
  print '   %.5f' % data['total (best)']
  print '   %.5f' % data['total (sd)']
  print ' (%.5f)' % data['real (avg)']
  print data['total (+/-)'] ? ' [%+0.1f%%]' % data['real (+/-)'] : ' [-----]'
  print data['real (significant?)'] ? '*' : ' '
  print ' (%.5f)' % data['real (best)']
  print ' (%.5f)' % data['real (sd)']
  puts
end

if previous
  puts
  puts '*Significant difference indicated with a star.'
end
