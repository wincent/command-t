# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'spec_helper'
require 'command-t/ext'

describe CommandT::Match do
  def match_for path, pattern
    CommandT::Match.new path, pattern
  end

  it 'requires pattern to be lowercase' do
    # this is an optimization: we ask our caller (the Matcher class) to
    # downcase once before calling us, rather than downcase repeatedly
    # during looping, recursion, and initialization of thousands of Match
    # instances
    match_for('foo', 'Foo').matches?.should == false
  end

  describe '#matches?' do
    it 'returns false for non-matches' do
      match_for('foo', 'bar').matches?.should == false
    end

    it 'returns true for matches' do
      match_for('foo', 'foo').matches?.should == true
    end

    it 'returns true for empty search strings' do
      match_for('foo', '').matches?.should == true
    end

    it 'returns false for overlength matches' do
      match_for('foo', 'foo...').matches?.should == false
    end
  end

  describe 'score method' do
    it 'assigns a score of 1.0 for empty search string' do
      match_for('foo', '').score.should == 1.0
    end

    it 'assigns a score of zero for a non-match' do
      match_for('foo', 'bar').score.should == 0.0
    end

    it 'assigns a score of zero for an overlength match' do
      match_for('foo', 'foo...').score.should == 0.0
    end

    it 'assigns perfect matches a score of one' do
      match_for('foo', 'foo').score.should == 1.0
    end

    it 'assigns perfect but incomplete matches a score of less than one' do
      match_for('foo', 'f').score.should < 1.0
    end

    it 'prioritizes matches with more matching characters' do
      few_matches = match_for('foobar', 'fb')
      many_matches = match_for('foobar', 'fbar')
      many_matches.score.should > few_matches.score
    end

    it 'prioritizes shorter paths over longer ones' do
      short_path = match_for('article.rb', 'art')
      long_path  = match_for('articles_controller_spec.rb', 'art')
      short_path.score.should > long_path.score
    end

    it 'prioritizes matches after "/"' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo/bar', 'b')
      special_match.score.should > normal_match.score

      # note that / beats _
      normal_match = match_for('foo_bar', 'b')
      special_match = match_for('foo/bar', 'b')
      special_match.score.should > normal_match.score

      # / also beats -
      normal_match = match_for('foo-bar', 'b')
      special_match = match_for('foo/bar', 'b')
      special_match.score.should > normal_match.score

      # and numbers
      normal_match = match_for('foo9bar', 'b')
      special_match = match_for('foo/bar', 'b')
      special_match.score.should > normal_match.score

      # and periods
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo/bar', 'b')
      special_match.score.should > normal_match.score

      # and spaces
      normal_match = match_for('foo bar', 'b')
      special_match = match_for('foo/bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'prioritizes matches after "-"' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo-bar', 'b')
      special_match.score.should > normal_match.score

      # - also beats .
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo-bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'prioritizes matches after "_"' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo_bar', 'b')
      special_match.score.should > normal_match.score

      # _ also beats .
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo_bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'prioritizes matches after " "' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo bar', 'b')
      special_match.score.should > normal_match.score

      # " " also beats .
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'prioritizes matches after numbers' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo9bar', 'b')
      special_match.score.should > normal_match.score

      # numbers also beat .
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo9bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'prioritizes matches after periods' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo.bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'prioritizes matching capitals following lowercase' do
      normal_match = match_for('foobar', 'b')
      special_match = match_for('fooBar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'prioritizes matches earlier in the string' do
      early_match = match_for('**b*****', 'b')
      late_match  = match_for('******b*', 'b')
      early_match.score.should > late_match.score
    end

    it 'prioritizes matches closer to previous matches' do
      early_match = match_for('**bc****', 'bc')
      late_match  = match_for('**b***c*', 'bc')
      early_match.score.should > late_match.score
    end

    it 'scores alternative matches of same path differently' do
      # given path:                    app/controllers/articles_controller.rb
      left_to_right_match = match_for('a**/****r******/**t*c***_*on*******.**', 'artcon')
      best_match          = match_for('***/***********/art*****_con*******.**', 'artcon')
      best_match.score.should > left_to_right_match.score
    end

    it 'returns the best possible score among alternatives' do
      # given path:                    app/controllers/articles_controller.rb
      best_match          = match_for('***/***********/art*****_con*******.**', 'artcon')
      chosen_match        = match_for('app/controllers/articles_controller.rb', 'artcon')
      chosen_match.score.should == best_match.score
    end

    it 'provides intuitive results for "artcon" and "articles_controller"' do
      low  = match_for('app/controllers/heartbeat_controller.rb', 'artcon')
      high = match_for('app/controllers/articles_controller.rb', 'artcon')
      high.score.should > low.score
    end

    it 'provides intuitive results for "aca" and "a/c/articles_controller"' do
      low         = match_for 'app/controllers/heartbeat_controller.rb', 'aca'
      high        = match_for 'app/controllers/articles_controller.rb', 'aca'
      best_match  = match_for 'a**/c**********/a******************.**', 'aca'
      high.score.should > low.score
      high.score.should == best_match.score
    end

    it 'provides intuitive results for "d" and "doc/command-t.txt"' do
      low  = match_for 'TODO', 'd'
      high = match_for 'doc/command-t.txt', 'd'
      high.score.should > low.score
    end

    it 'provides intuitive results for "do" and "doc/command-t.txt"' do
      low  = match_for 'TODO', 'do'
      high = match_for 'doc/command-t.txt', 'do'
      high.score.should > low.score
    end
  end

  describe 'to_s method' do
    it 'returns the entire matched string' do
      match_for('abc', 'abc').to_s.should == 'abc'
    end
  end
end
