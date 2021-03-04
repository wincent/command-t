# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'ostruct'

describe CommandT::Scanner::BufferScanner do
  def buffer(name)
    b = OpenStruct.new
    b.name = name
    b
  end

  before do
    @paths = %w(bar/abc bar/xyz baz bing foo/alpha/t1 foo/alpha/t2 foo/beta)
    @scanner = CommandT::Scanner::BufferScanner.new
    allow(@scanner).to receive(:relative_path_under_working_directory).with(kind_of(String)) { |arg| arg }
    allow(::VIM::Buffer).to receive(:count) { 7 }
    (0..6).each do |n|
      allow(::VIM::Buffer).to receive(:'[]').with(n).and_return(buffer @paths[n])
    end
  end

  describe 'paths method' do
    it 'returns a list of regular files' do
      expect(@scanner.paths).to match_array(@paths)
    end
  end
end
