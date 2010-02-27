require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe CommandT::Match do
  def matcher_for path, pattern
    # reuse Matcher code rather than replicate it
    regexp = CommandT::Matcher.regexp_for pattern
    CommandT::Match.new(regexp.match(path))
  end

  describe 'score method' do
    it 'should assign non-matches a score of zero' do
      matcher_for('./foo', 'bar').score.should == 0.0
    end

    it 'should assign perfect matches a score of one' do
      matcher_for('./foo', './foo').score.should == 1.0
    end
  end

  describe 'to_s method' do
    it 'should return the entire matched string' do
      matcher_for('abc', 'abc').to_s.should == 'abc'
    end
  end
end
