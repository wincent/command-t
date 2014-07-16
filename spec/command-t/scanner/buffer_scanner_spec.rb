# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'ostruct'
require 'command-t/scanner/buffer_scanner'

describe CommandT::BufferScanner do
  def buffer name
    b = OpenStruct.new
    b.name = name
    b
  end

  before do
    @paths = %w(bar/abc bar/xyz baz bing foo/alpha/t1 foo/alpha/t2 foo/beta)
    @scanner = CommandT::BufferScanner.new
    stub(@scanner).relative_path_under_working_directory(is_a(String)) { |arg| arg }
    stub(::VIM::Buffer).count { 7 }
    (0..6).each do |n|
      stub(::VIM::Buffer)[n].returns(buffer @paths[n])
    end
  end

  describe 'paths method' do
    it 'returns a list of regular files' do
      @scanner.paths.should =~ @paths
    end
  end
end
