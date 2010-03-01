require File.join(File.dirname(__FILE__), '..', 'spec_helper')

describe CommandT::Matcher do
  describe 'initialization' do
    it 'should raise an ArgumentError if passed nil' do
      lambda { CommandT::Matcher.new nil }.
        should raise_error(ArgumentError)
    end
  end

  describe 'regexp_for method' do
    it 'should insert globs before and after every character' do
      CommandT::Matcher.regexp_for('foo').should == /\A.*?(f).*?(o).*?(o).*?\z/i
    end

    it 'should return a greedy match-all regexp for empty search string' do
      CommandT::Matcher.regexp_for('').should == /.*/ # match all files
    end

    it 'should raise an ArgumentError if passed nil' do
      lambda { CommandT::Matcher.regexp_for(nil) }.
        should raise_error(ArgumentError)
    end

    it 'should escape characters which have special meaning' do
      CommandT::Matcher.regexp_for('.rb').should == /\A.*?(\.).*?(r).*?(b).*?\z/i
    end
  end

  describe 'matches_for method' do
    before :each do
      @scanner = mock(CommandT::Scanner::Base)
    end

    it 'should raise an ArgumentError if passed nil' do
      @matcher = CommandT::Matcher.new @scanner
      lambda { @matcher.matches_for(nil) }.
        should raise_error(ArgumentError)
    end

    it 'should return empty array when source array empty' do
      @scanner.stub(:paths).and_return([])
      @no_paths = CommandT::Matcher.new @scanner
      @no_paths.matches_for('foo').should == []
      @no_paths.matches_for('').should == []
    end

    it 'should return empty array when no matches' do
      @scanner.stub(:paths).and_return(['./foo/bar', './foo/baz', './bing'])
      @no_matches = CommandT::Matcher.new @scanner
      @no_matches.matches_for('xyz').should == []
    end

    it 'should return matching paths' do
      @scanner.stub(:paths).and_return(['./foo/bar', './foo/baz', './bing'])
      @foo_paths = CommandT::Matcher.new @scanner
      matches = @foo_paths.matches_for('z')
      matches.map { |m| m.to_s }.should == ['./foo/baz']
      matches = @foo_paths.matches_for('bg')
      matches.map { |m| m.to_s }.should == ['./bing']
    end

    it 'should perform case-insensitive matching' do
      @scanner.stub(:paths).and_return(['./Foo'])
      @path = CommandT::Matcher.new @scanner
      matches = @path.matches_for('f')
      matches.map { |m| m.to_s }.should == ['./Foo']
    end
  end

  describe 'sorted_matches_for method' do
    it 'should return matches in score order'
    it 'should return matches in alphabetical order if no search string is supplied'
  end
end
