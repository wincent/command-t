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

require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe CommandT::Match do
  def match_for path, pattern
    CommandT::Match.new path, pattern
  end

  describe 'matches? method' do
    it 'should return false for non-matches' do
      match_for('foo', 'bar').matches?.should == false
    end

    it 'should return true for matches' do
      match_for('foo', 'foo').matches?.should == true
    end

    it 'should return true for empty search strings' do
      match_for('foo', '').matches?.should == true
    end
  end

  describe 'score method' do
    it 'should assign a score of zero for empty search string' do
      match_for('foo', '').score.should == 0.0
    end

    it 'should assign a score of zero for a non-match' do
      match_for('foo', 'bar').score.should == 0.0
    end

    it 'should assign perfect matches a score of one' do
      match_for('foo', 'foo').score.should == 1.0
    end

    it 'should prioritize matches with more matching characters' do
      few_matches = match_for('foobar', 'fb')
      many_matches = match_for('foobar', 'fbar')
      many_matches.score.should > few_matches.score
    end

    it 'should prioritize matches after "/"' do
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

    it 'should prioritize matches after "-"' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo-bar', 'b')
      special_match.score.should > normal_match.score

      # - also beats .
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo-bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after "_"' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo_bar', 'b')
      special_match.score.should > normal_match.score

      # _ also beats .
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo_bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after " "' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo bar', 'b')
      special_match.score.should > normal_match.score

      # " " also beats .
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after numbers' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo9bar', 'b')
      special_match.score.should > normal_match.score

      # numbers also beat .
      normal_match = match_for('foo.bar', 'b')
      special_match = match_for('foo9bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after periods' do
      normal_match = match_for('fooobar', 'b')
      special_match = match_for('foo.bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matching capitals following lowercase' do
      normal_match = match_for('foobar', 'b')
      special_match = match_for('fooBar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches earlier in the string' do
      early_match = match_for('**b*****', 'b')
      late_match  = match_for('******b*', 'b')
      early_match.score.should > late_match.score
    end

    it 'should prioritize matches closer to previous matches' do
      early_match = match_for('**bc****', 'bc')
      late_match  = match_for('**b***c*', 'bc')
      early_match.score.should > late_match.score
    end
  end

  describe 'offsets accessor' do
    it 'should contain the indices of the matched characters (consecutive)' do
      match_for('abc', 'abc').offsets.should == [0, 1, 2]
    end

    it 'should contain the indices of the matched characters (separated)' do
      match_for('foobar', 'fb').offsets.should == [0, 3]
    end

    it 'should be empty for zero-width search strings' do
      match_for('foo', '').offsets.should be_empty
    end

    it 'should not allow one character to match repeatedly' do
      # was a bug in one of the refactorings
      # the "b" in "abc" would match both the first and second "b" in "abb"
      match_for('abc', 'abb').matches?.should == false
    end
  end

  describe 'to_s method' do
    it 'should return the entire matched string' do
      match_for('abc', 'abc').to_s.should == 'abc'
    end
  end
end
