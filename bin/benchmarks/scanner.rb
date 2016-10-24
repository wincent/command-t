#!/usr/bin/env ruby
#
# Copyright 2013-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require_relative 'base.rb'

class CommandT::ProgressReporter
  def update t
    t + 1e9
  end
end

class MatcherBenchmark < CommandT::Benchmark
  TIMES = 5

  TYPE  = ENV.fetch 'TYPE', 'ruby'
  DIR   = ENV.fetch 'DIR', '/usr'

  def exec b
    scanner = CommandT::Scanner::FileScanner
      .for_scanner_type(TYPE)
      .new DIR,
        max_files: 1e9,
        git_scan_submodules: ENV.fetch('SUBMODULES', false),
        git_include_untracked: ENV.fetch('UNTRACKED', false)

    begin
      puts scanner.send :command
    rescue
    end

    b.report do
      scanner.flush
      scanner.c_paths
    end
  end
end

MatcherBenchmark.new.run
