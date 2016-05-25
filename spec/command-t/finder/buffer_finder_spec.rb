# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'

describe CommandT::Finder::BufferFinder do
  before do
    @paths = %w(.git/config .vim/notes .vimrc baz foo/beta)
    any_instance_of(CommandT::Scanner::BufferScanner, :paths => @paths)
    @finder = CommandT::Finder::BufferFinder.new
  end

  describe 'sorted_matches_for method' do
    it 'returns an empty array when no matches' do
      expect(@finder.sorted_matches_for('kung foo fighting')).to eq([])
    end

    it 'returns all files when query string is empty' do
      expect(@finder.sorted_matches_for('')).to eq(@paths)
    end

    it 'returns files in alphabetical order when query string is empty' do
      results = @finder.sorted_matches_for('')
      expect(results).to eq(results.sort)
    end

    it 'returns matching files in score order' do
      expect(@finder.sorted_matches_for('ba')).to eq(%w(baz foo/beta))
      expect(@finder.sorted_matches_for('a')).to eq(%w(baz foo/beta))
    end

    it 'returns matching dot files even when search term does not include a dot' do
      expect(@finder.sorted_matches_for('i')).to include('.vimrc')
    end

    it 'returns matching files inside dot directories even when search term does not include a dot' do
      expect(@finder.sorted_matches_for('i')).to include('.vim/notes')
    end

    it "does not consult the 'wildignore' setting" do
      expect(@finder.sorted_matches_for('').count).to eq(5)
    end

    it 'obeys the :limit option for empty search strings' do
      expect(@finder.sorted_matches_for('', :limit => 1)).
        to eq(%w(.git/config))
    end

    it 'obeys the :limit option for non-empty search strings' do
      expect(@finder.sorted_matches_for('i', :limit => 2)).
        to eq(%w(.vimrc .vim/notes))
    end
  end
end
