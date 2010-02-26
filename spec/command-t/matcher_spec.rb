require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe CommandT::Matcher do
  describe 'regexp_for method' do
    it 'should insert globs before and after every character' do
      CommandT::Matcher.regexp_for('foo').should == /.*(f).*(o).*(o).*/i
    end

    it 'should return empty regexp for empty search string' do
      CommandT::Matcher.regexp_for('').should == // # match all files
    end

    it 'should raise an ArgumentError if passed nil' do
      lambda { CommandT::Matcher.regexp_for(nil) }.
        should raise_error(ArgumentError)
    end

    it 'should escape characters which have special meaning' do
      CommandT::Matcher.regexp_for('.rb').should == /.*(\.).*(r).*(b).*/i
    end
  end

  describe 'matches_for method' do
    it 'should raise an ArgumentError if passed nil' do
      @matcher = CommandT::Matcher.new
      lambda { @matcher.matches_for(nil) }.
        should raise_error(ArgumentError)
    end

    it 'should return empty array when source array empty' do
      @no_paths = CommandT::Matcher.new
      @no_paths.matches_for('foo').should == []
      @no_paths.matches_for('').should == []
    end

    it 'should return empty array when no matches' do
      @no_matches = CommandT::Matcher.new './foo', './bar'
      @no_matches.matches_for('xyz').should == []
    end

    it 'should return matching paths' do
      @foo_paths = CommandT::Matcher.new './foo/bar', './foo/baz', './bing'
      @foo_paths.matches_for('z').should == ['./foo/baz']
      @foo_paths.matches_for('bg').should == ['./bing']
    end
  end
end
