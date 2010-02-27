require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe CommandT::Match do
  describe 'score method' do
    it 'should assign non-matches a score of zero' do
      CommandT::Match.new(nil).score.should == 0.0
    end
  end

  describe 'to_s method' do
    it 'should return the entire matched string' do
      regexp = /foo\d+/
      match = regexp.match 'foo123'
      CommandT::Match.new(match).to_s.should == 'foo123'
    end
  end
end
