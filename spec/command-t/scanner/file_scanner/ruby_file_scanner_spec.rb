# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'command-t/scanner/file_scanner/ruby_file_scanner'

describe CommandT::FileScanner::RubyFileScanner do
  before do
    @dir = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'fixtures')
    @all_fixtures = %w(
      bar/abc bar/xyz baz bing foo/alpha/t1 foo/alpha/t2 foo/beta
    )
    @scanner = CommandT::FileScanner::RubyFileScanner.new(@dir)

    stub(::VIM).evaluate(/exists/) { 1 }
    stub(::VIM).evaluate(/expand\(.+\)/) { '0' }
    stub(::VIM).evaluate(/wildignore/) { '' }
  end

  describe 'paths method' do
    it 'returns a list of regular files' do
      @scanner.paths.should =~ @all_fixtures
    end
  end

  describe 'path= method' do
    it 'allows repeated applications of scanner at different paths' do
      @scanner.paths.should =~ @all_fixtures

      # drill down 1 level
      @scanner.path = File.join(@dir, 'foo')
      @scanner.paths.should =~ %w(alpha/t1 alpha/t2 beta)

      # and another
      @scanner.path = File.join(@dir, 'foo', 'alpha')
      @scanner.paths.should =~ %w(t1 t2)
    end
  end

  describe "'wildignore' exclusion" do
    context "when there is a 'wildignore' setting in effect" do
      it "calls on VIM's expand() function for pattern filtering" do
        stub(::VIM).command(/set wildignore/)
        scanner =
          CommandT::FileScanner::RubyFileScanner.new @dir, :wild_ignore => '*.o'
        mock(::VIM).evaluate(/expand\(.+\)/).times(10)
        scanner.paths
      end
    end

    context "when there is no 'wildignore' setting in effect" do
      it "does not call VIM's expand() function" do
        scanner = CommandT::FileScanner::RubyFileScanner.new @dir
        mock(::VIM).evaluate(/expand\(.+\)/).never
        scanner.paths
      end
    end
  end

  describe ':max_depth option' do
    it 'does not descend below "max_depth" levels' do
      @scanner = CommandT::FileScanner::RubyFileScanner.new @dir, :max_depth => 1
      @scanner.paths.should =~ %w(bar/abc bar/xyz baz bing foo/beta)
    end
  end
end
