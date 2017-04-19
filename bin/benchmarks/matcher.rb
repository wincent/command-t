#!/usr/bin/env ruby
#
# Copyright 2013-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

%w[ext lib].each do |dir|
  path  = File.expand_path("../../ruby/command-t/#{dir}", File.dirname(__FILE__))
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end

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

TIMES = ENV.fetch('TIMES', 20).to_i
results = TIMES.times.map do
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
def significance(last, current)
  return 0.0 if last.length != current.length

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
  table = table.map do |row|
    count = 0
    rank = table.map.with_index do |(diff, abs, sig), i|
      if abs == row[ABSOLUTE]
        count += 1
        i + 1
      else
        nil
      end
    end.compact.reduce(0) { |acc, val| acc + val }.to_f / count
    row + [row[SIGN] * rank]
  end

  n = table.length
  w = table.reduce(0) { |acc, (diff, abs, sig, signed_rank)| acc + signed_rank }

  if n < 10
    p_value = 0
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
      if w.abs >= limit[0]
        p_value = limit[1]
        break
      end
    end
  else
    sd = Math.sqrt(n * (n + 1) *  (2 * n + 1) / 6)
    z = ((w - 0.5) / sd).abs
    if z >= 3.291
      p_value = 0.0005
    elsif z >= 2.576
      p_value = 0.005
    elsif z >= 2.326
      p_value = 0.01
    elsif z >= 1.960
      p_value = 0.025
    elsif z >= 1.645
      p_value = 0.05
    else
      p_value = 0
    end
  end

  p_value
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
  test['real (+/-)'] = previous && previous[label] &&
    (test['real (avg)'] - previous[label]['real (avg)']) / test['real (avg)'] * 100
  test['real (significance)'] = significance(previous[label]['real'], test['real']) if previous && previous[label]
  test['total (avg)'] = test['total'].reduce(:+) / test['total'].length
  test['total (+/-)'] = previous && previous[label] &&
    (test['total (avg)'] - previous[label]['total (avg)']) / test['total (avg)'] * 100
  test['total (significance)'] = significance(previous[label]['total'], test['total']) if previous && previous[label]

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

def print_table(rows)
  rows.each do |row|
    row.each.with_index do |cell, i|
      width = rows.reduce(0) { |acc, row| row[i].length > acc ? row[i].length : acc }
      if i.zero?
        print align(cell, width)
      else
        print(' ' + align(cell, width))
      end
    end
    puts
  end
end

def align(str, width)
  if str.respond_to?(:justify)
    case str.justify
    when :center
      ('%*s%s%*s' % [
        ((width - str.length) / 2.0).round,
        '',
        str,
        ((width - str.length) / 2.0).round,
        '',
      ])[0...width]
    when :left
      '%-*s' % [width, str]
    else
      '%*s' % [width, str]
    end
  else
    '%*s' % [width, str]
  end
end

AnnotatedString = Struct.new(:length, :to_s, :justify)
def center(str)
  AnnotatedString.new(str.length, str, :center)
end

def float(x)
  '%.5f' % x
end

def parens(x)
  "(#{x})"
end

def trim(str)
  str.sub(/0+\z/, '')
end

def maybe(value, default = '')
  if value
    yield value
  else
    default
  end
end

puts "\n\nSummary of cpu time and (wall-clock time):\n"

headers = [
  [
    '',
    center('best'),
    center('avg'),
    center('sd'),
    center('+/-'),
    center('p'),
    center('(best)'),
    center('(avg)'),
    center('(sd)'),
    center('+/-'),
    center('p'),
  ]
]
rows = headers + results.map do |(label, data)|
  [
    label,
    float(data['total (best)']),
    float(data['total (avg)']),
    float(data['total (sd)']),
    maybe(data['total (+/-)'], center('?')) { |value| '[%+0.1f%%]' % value },
    maybe(data['total (significance)']) { |value| value > 0 ? trim(float(value)) : '' },
    parens(float(data['real (best)'])),
    parens(float(data['real (avg)'])),
    parens(float(data['real (sd)'])),
    maybe(data['real (+/-)'], center('?')) { |value| '[%+0.1f%%]' % value },
    maybe(data['real (significance)']) { |value| value > 0 ? trim(float(value)) : '' },
  ]
end
print_table(rows)
