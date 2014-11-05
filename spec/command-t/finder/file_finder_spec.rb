# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'

describe CommandT::Finder::FileFinder do
  before :all do
    @finder = CommandT::Finder::FileFinder.new File.join(File.dirname(__FILE__), '..',
      '..', '..', 'fixtures')
    @all_fixtures = %w(
      bar/abc
      bar/xyz
      baz
      bing
      foo/alpha/t1
      foo/alpha/t2
      foo/beta
    )
  end

  before do
    stub(::VIM).evaluate(/expand/) { 0 }
  end

  describe 'sorted_matches_for method' do
    it 'returns an empty array when no matches' do
      @finder.sorted_matches_for('kung foo fighting').should == []
    end

    it 'returns all files when query string is empty' do
      @finder.sorted_matches_for('').should == @all_fixtures
    end

    it 'returns files in alphabetical order when query string is empty' do
      results = @finder.sorted_matches_for('')
      results.should == results.sort
    end

    it 'returns matching files in score order' do
      @finder.sorted_matches_for('ba').
        should == %w(baz bar/abc bar/xyz foo/beta)
      @finder.sorted_matches_for('a').
        should == %w(baz bar/abc bar/xyz foo/alpha/t1 foo/alpha/t2 foo/beta)
    end

    it 'obeys the :limit option for empty search strings' do
      @finder.sorted_matches_for('', :limit => 2).
        should == %w(bar/abc bar/xyz)
    end

    it 'obeys the :limit option for non-empty search strings' do
      @finder.sorted_matches_for('a', :limit => 3).
        should == %w(baz bar/abc bar/xyz)
    end
  end
end
