# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'
require 'ostruct'
require 'command-t/ext' # CommandT::Matcher

describe CommandT::Matcher do
  def matcher(*paths)
    scanner = OpenStruct.new(:paths => paths)
    CommandT::Matcher.new(scanner)
  end

  describe 'initialization' do
    it 'raises an ArgumentError if passed nil' do
      expect { CommandT::Matcher.new(nil) }.to raise_error(ArgumentError)
    end
  end

  describe '#sorted_matches_for' do
    def ordered_matches(paths, query)
      matcher(*paths).sorted_matches_for(query)
    end

    it 'raises an ArgumentError if passed nil' do
      expect { matcher.sorted_matches_for(nil) }.to raise_error(ArgumentError)
    end

    it 'returns empty array when source array empty' do
      matcher.sorted_matches_for('foo').should == []
      matcher.sorted_matches_for('').should == []
    end

    it 'returns empty array when no matches' do
      matcher = matcher(*%w[foo/bar foo/baz bing])
      matcher.sorted_matches_for('xyz').should == []
    end

    it 'returns matching paths' do
      matcher = matcher(*%w[foo/bar foo/baz bing])
      matches = matcher.sorted_matches_for('z')
      matches.map { |m| m.to_s }.should == ['foo/baz']
      matches = matcher.sorted_matches_for('bg')
      matches.map { |m| m.to_s }.should == ['bing']
    end

    it 'performs case-insensitive matching' do
      matches = matcher('Foo').sorted_matches_for('f')
      matches.map { |m| m.to_s }.should == ['Foo']
    end

    it 'considers the empty string to match everything' do
      matches = matcher('foo').sorted_matches_for('')
      matches.map { |m| m.to_s }.should == ['foo']
    end

    it 'does not consider mere substrings of the query string to be a match' do
      matcher('foo').sorted_matches_for('foo...').should == []
    end

    it 'prioritizes shorter paths over longer ones' do
      ordered_matches(%w[
        articles_controller_spec.rb
        article.rb
      ], 'art').should == %w[
        article.rb
        articles_controller_spec.rb
      ]
    end

    it 'prioritizes matches after "/"' do
      ordered_matches(%w[fooobar foo/bar], 'b').should == %w[foo/bar fooobar]

      # note that / beats _
      ordered_matches(%w[foo_bar foo/bar], 'b').should == %w[foo/bar foo_bar]

      # / also beats -
      ordered_matches(%w[foo-bar foo/bar], 'b').should == %w[foo/bar foo-bar]

      # and numbers
      ordered_matches(%w[foo9bar foo/bar], 'b').should == %w[foo/bar foo9bar]

      # and periods
      ordered_matches(%w[foo.bar foo/bar], 'b').should == %w[foo/bar foo.bar]

      # and spaces
      ordered_matches(['foo bar', 'foo/bar'], 'b').should == ['foo/bar', 'foo bar']
    end

    it 'prioritizes matches after "-"' do
      ordered_matches(%w[fooobar foo-bar], 'b').should == %w[foo-bar fooobar]

      # - also beats .
      ordered_matches(%w[foo.bar foo-bar], 'b').should == %w[foo-bar foo.bar]
    end

    it 'prioritizes matches after "_"' do
      ordered_matches(%w[fooobar foo_bar], 'b').should == %w[foo_bar fooobar]

      # _ also beats .
      ordered_matches(%w[foo.bar foo_bar], 'b').should == %w[foo_bar foo.bar]
    end

    it 'prioritizes matches after " "' do
      ordered_matches(['fooobar', 'foo bar'], 'b').should == ['foo bar', 'fooobar']

      # " " also beats .
      ordered_matches(['foo.bar', 'foo bar'], 'b').should == ['foo bar', 'foo.bar']
    end

    it 'prioritizes matches after numbers' do
      ordered_matches(%w[fooobar foo9bar], 'b').should == %w[foo9bar fooobar]

      # numbers also beat .
      ordered_matches(%w[foo.bar foo9bar], 'b').should == %w[foo9bar foo.bar]
    end

    it 'prioritizes matches after periods' do
      ordered_matches(%w[fooobar foo.bar], 'b').should == %w[foo.bar fooobar]
    end

    it 'prioritizes matching capitals following lowercase' do
      ordered_matches(%w[foobar fooBar], 'b').should == %w[fooBar foobar]
    end

    it 'prioritizes matches earlier in the string' do
      ordered_matches(%w[******b* **b*****], 'b').should == %w[**b***** ******b*]
    end

    it 'prioritizes matches closer to previous matches' do
      ordered_matches(%w[**b***c* **bc****], 'bc').should == %w[**bc**** **b***c*]
    end

    it 'scores alternative matches of same path differently' do
      # ie:
      # app/controllers/articles_controller.rb
      ordered_matches(%w[
        a**/****r******/**t*c***_*on*******.**
        ***/***********/art*****_con*******.**
      ], 'artcon').should == %w[
        ***/***********/art*****_con*******.**
        a**/****r******/**t*c***_*on*******.**
      ]
    end

    it 'provides intuitive results for "artcon" and "articles_controller"' do
      ordered_matches(%w[
        app/controllers/heartbeat_controller.rb
        app/controllers/articles_controller.rb
      ], 'artcon').should == %w[
        app/controllers/articles_controller.rb
        app/controllers/heartbeat_controller.rb
      ]
    end

    it 'provides intuitive results for "aca" and "a/c/articles_controller"' do
      ordered_matches(%w[
        app/controllers/heartbeat_controller.rb
        app/controllers/articles_controller.rb
      ], 'aca').should == %w[
        app/controllers/articles_controller.rb
        app/controllers/heartbeat_controller.rb
      ]
    end

    it 'provides intuitive results for "d" and "doc/command-t.txt"' do
      ordered_matches(%w[
        TODO
        doc/command-t.txt
      ], 'd').should == %w[
        doc/command-t.txt
        TODO
      ]
    end

    it 'provides intuitive results for "do" and "doc/command-t.txt"' do
      ordered_matches(%w[
        TODO
        doc/command-t.txt
      ], 'do').should == %w[
        doc/command-t.txt
        TODO
      ]
    end

    it "doesn't incorrectly accept repeats of the last-matched character" do
      # https://github.com/wincent/Command-T/issues/82
      matcher = matcher(*%w[ash/system/user/config.h])
      matcher.sorted_matches_for('usercc').should == []

      # simpler test case
      matcher = matcher(*%w[foobar])
      matcher.sorted_matches_for('fooooo').should == []

      # minimal repro
      matcher = matcher(*%w[ab])
      matcher.sorted_matches_for('aa').should == []
    end

    it 'ignores dotfiles by default' do
      matcher = matcher(*%w[.foo .bar])
      matcher.sorted_matches_for('foo').should == []
    end

    it 'shows dotfiles if the query starts with a dot' do
      matcher = matcher(*%w[.foo .bar])
      matcher.sorted_matches_for('.fo').should == %w[.foo]
    end

    it "doesn't show dotfiles if the query contains a non-leading dot" do
      matcher = matcher(*%w[.foo.txt .bar.txt])
      matcher.sorted_matches_for('f.t').should == []

      # counter-example
      matcher.sorted_matches_for('.f.t').should == %w[.foo.txt]
    end
  end
end
