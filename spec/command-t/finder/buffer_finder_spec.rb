# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'command-t/finder/buffer_finder'

describe CommandT::BufferFinder do
  before do
    @paths = %w(.git/config .vim/notes .vimrc baz foo/beta)
    any_instance_of(CommandT::BufferScanner, :paths => @paths)
    @finder = CommandT::BufferFinder.new
  end

  describe 'sorted_matches_for method' do
    it 'returns an empty array when no matches' do
      @finder.sorted_matches_for('kung foo fighting').should == []
    end

    it 'returns all files when query string is empty' do
      @finder.sorted_matches_for('').should == @paths
    end

    it 'returns files in alphabetical order when query string is empty' do
      results = @finder.sorted_matches_for('')
      results.should == results.sort
    end

    it 'returns matching files in score order' do
      @finder.sorted_matches_for('ba').should == %w(baz foo/beta)
      @finder.sorted_matches_for('a').should == %w(baz foo/beta)
    end

    it 'returns matching dot files even when search term does not include a dot' do
      @finder.sorted_matches_for('i').should include('.vimrc')
    end

    it 'returns matching files inside dot directories even when search term does not include a dot' do
      @finder.sorted_matches_for('i').should include('.vim/notes')
    end

    it "does not use the Vim expand() function to consult the 'wildignore' setting" do
      do_not_allow(::VIM).evaluate
      @finder.sorted_matches_for('i')
    end

    it 'obeys the :limit option for empty search strings' do
      @finder.sorted_matches_for('', :limit => 1).
        should == %w(.git/config)
    end

    it 'obeys the :limit option for non-empty search strings' do
      @finder.sorted_matches_for('i', :limit => 2).
        should == %w(.vimrc .vim/notes)
    end
  end
end
