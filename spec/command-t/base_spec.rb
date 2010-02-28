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

  describe 'matches_for method' do
    it 'should return an empty array when no matches' do
      @base.matches_for('kung foo fighting').should == []
    end

    it 'should return all files when query string is empty' do
      matches = @base.matches_for('')
      matches.map { |m| m.to_s }.should == @all_fixtures
    end

    it 'should return files in alphabetical order when query string is empty' do
      matches = @base.matches_for('')
      matches = matches.map { |m| m.to_s }
      matches.should == matches.sort
    end

    it 'should return matching files' do
      matches = @base.matches_for('ba')
      matches.map { |m| m.to_s}.should == ['bar/abc', 'bar/xyz', 'baz',
        'foo/beta']
    end
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
        'foo/alpha/t2', 'bar/abc', 'baz', 'bar/xyz', 'foo/beta']
    end

    it 'should obey the :limit option for empty search strings'
    it 'should obey the :limit option for non-empty search strings'
  end
end
