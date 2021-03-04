# Copyright 2015-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'

describe CommandT::Scanner::FileScanner::WatchmanFileScanner do
  context 'when an error occurs' do
    it 'falls back to the FindFileScanner' do
      # fake an error
      scanner = described_class.new
      allow(scanner).to receive(:get_raw_sockname) do
        raise described_class::WatchmanError
      end

      # expect call on superclass
      expect_any_instance_of(CommandT::Scanner::FileScanner::FindFileScanner).to receive(:paths!)

      scanner.paths!
    end
  end
end
