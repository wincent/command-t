# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'command-t/vim'

describe CommandT::VIM do
  describe '.escape_for_single_quotes' do
    it 'turns doubles all single quotes' do
      input = %{it's ''something''}
      expected = %{it''s ''''something''''}
      expect(CommandT::VIM.escape_for_single_quotes(input)).to eq(expected)
    end
  end
end
