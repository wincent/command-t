require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe CommandT::Base do
  before :all do
    @base = CommandT::Base.new File.join(File.dirname(__FILE__), '..',
      '..', 'fixtures')
    @all_fixtures = [
      'bar/abc',
      'bar/xyz',
      'baz',
      'bing',
      'foo/alpha/t1',
      'foo/alpha/t2',
      'foo/beta'
    ]
  end

  describe 'sorted_matches_for method' do
    it 'should return an empty array when no matches' do
      @base.sorted_matches_for('kung foo fighting').should == []
    end

    it 'should return all files when query string is empty' do
      @base.sorted_matches_for('').should == @all_fixtures
    end

    it 'should return files in alphabetical order when query string is empty' do
      results = @base.sorted_matches_for('')
      results.should == results.sort
    end

    it 'should return matching files in score order' do
      @base.sorted_matches_for('ba').should == ['bar/abc', 'bar/xyz', 'baz',
        'foo/beta']
      @base.sorted_matches_for('a').should == ['foo/alpha/t1',
        'foo/alpha/t2', 'bar/abc', 'bar/xyz', 'baz', 'foo/beta']
    end

    it 'should obey the :limit option for empty search strings' do
      @base.sorted_matches_for('', :limit => 2).should == ['bar/abc', 'bar/xyz']
    end

    it 'should obey the :limit option for non-empty search strings' do
      @base.sorted_matches_for('a', :limit => 3).should == ['foo/alpha/t1',
        'foo/alpha/t2', 'bar/abc']
    end
  end
end
