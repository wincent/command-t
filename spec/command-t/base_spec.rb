require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe CommandT::Base do
  before :all do
    @base = CommandT::Base.new File.join(File.dirname(__FILE__), '..',
      '..', 'fixtures')
    @all_fixtures = [
      './bar/abc',
      './bar/xyz',
      './baz',
      './bing',
      './foo/alpha/t1',
      './foo/alpha/t2',
      './foo/beta'
    ]
  end

  describe 'matches_for method' do
    it 'should return an empty array when no matches' do
      @base.matches_for('kung foo fighting').should == []
    end

    it 'should return all files when query string is empty' do
      @base.matches_for('').should == @all_fixtures
    end
  end
end
