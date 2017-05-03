# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'

describe CommandT::VIM do
  describe '.escape_for_single_quotes' do
    it 'turns doubles all single quotes' do
      input = %{it's ''something''}
      expected = %{it''s ''''something''''}
      expect(CommandT::VIM.escape_for_single_quotes(input)).to eq(expected)
    end
  end

  describe '.wildignore_to_regexp' do
    it 'properly matches directories at any level' do
      regexp = Regexp.new(CommandT::VIM.wildignore_to_regexp('*/foo/*'))
      expect(regexp).to match('some/path/to/foo/file.js')
      expect(regexp).to_not match('some/path/to/foo')
    end
  end
end
