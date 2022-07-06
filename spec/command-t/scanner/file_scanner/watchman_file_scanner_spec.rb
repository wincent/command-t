# SPDX-FileCopyrightText: Copyright 2015-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

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
