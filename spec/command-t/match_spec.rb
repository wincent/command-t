require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe CommandT::Match do
  def match_for path, pattern
    # reuse Matcher code rather than replicate it
    regexp = CommandT::Matcher.regexp_for pattern
    CommandT::Match.match path, regexp
  end

  describe 'match class method' do
    it 'should return a match with score zero for empty search string' do
      match_for('./foo', '').score.should == 0.0
    end

    it 'should return nil for non-matches' do
      match_for('./foo', 'bar').should be_nil
    end
  end

  describe 'score method' do
    it 'should assign perfect matches a score of one' do
      match_for('./foo', './foo').score.should == 1.0
    end

    it 'should prioritize matches with more matching characters' do
      few_matches = match_for('./foobar', 'fb')
      many_matches = match_for('./foobar', 'fbar')
      many_matches.score.should > few_matches.score
    end

    it 'should prioritize matches after "/"' do
      normal_match = match_for('./fooobar', 'b')
      special_match = match_for('./foo/bar', 'b')
      special_match.score.should > normal_match.score

      # note that / beats _
      normal_match = match_for('./foo_bar', 'b')
      special_match = match_for('./foo/bar', 'b')
      special_match.score.should > normal_match.score

      # / also beats -
      normal_match = match_for('./foo-bar', 'b')
      special_match = match_for('./foo/bar', 'b')
      special_match.score.should > normal_match.score

      # and numbers
      normal_match = match_for('./foo9bar', 'b')
      special_match = match_for('./foo/bar', 'b')
      special_match.score.should > normal_match.score

      # and periods
      normal_match = match_for('./foo.bar', 'b')
      special_match = match_for('./foo/bar', 'b')
      special_match.score.should > normal_match.score

      # and spaces
      normal_match = match_for('./foo bar', 'b')
      special_match = match_for('./foo/bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after "-"' do
      normal_match = match_for('./fooobar', 'b')
      special_match = match_for('./foo-bar', 'b')
      special_match.score.should > normal_match.score

      # - also beats .
      normal_match = match_for('./foo.bar', 'b')
      special_match = match_for('./foo-bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after "_"' do
      normal_match = match_for('./fooobar', 'b')
      special_match = match_for('./foo_bar', 'b')
      special_match.score.should > normal_match.score

      # _ also beats .
      normal_match = match_for('./foo.bar', 'b')
      special_match = match_for('./foo_bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after " "' do
      normal_match = match_for('./fooobar', 'b')
      special_match = match_for('./foo bar', 'b')
      special_match.score.should > normal_match.score

      # " " also beats .
      normal_match = match_for('./foo.bar', 'b')
      special_match = match_for('./foo bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after numbers' do
      normal_match = match_for('./fooobar', 'b')
      special_match = match_for('./foo9bar', 'b')
      special_match.score.should > normal_match.score

      # numbers also beat .
      normal_match = match_for('./foo.bar', 'b')
      special_match = match_for('./foo9bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matches after periods' do
      normal_match = match_for('./fooobar', 'b')
      special_match = match_for('./foo.bar', 'b')
      special_match.score.should > normal_match.score
    end

    it 'should prioritize matching capitals following lowercase' do
      normal_match = match_for('./foobar', 'b')
      special_match = match_for('./fooBar', 'b')
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

  describe 'to_s method' do
    it 'should return the entire matched string' do
      match_for('abc', 'abc').to_s.should == 'abc'
    end
  end
end
