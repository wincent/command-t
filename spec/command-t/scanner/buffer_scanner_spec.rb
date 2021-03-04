# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'ostruct'

describe CommandT::Scanner::BufferScanner do
  before do
    @paths = %w(bar/abc bar/xyz baz bing foo/alpha/t1 foo/alpha/t2 foo/beta)
    @scanner = CommandT::Scanner::BufferScanner.new
    allow(@scanner).to receive(:paths!).and_return(@paths)
  end

  describe 'paths method' do
    it 'returns a list of regular files' do
      expect(@scanner.paths).to match_array(@paths)
    end
  end
end
