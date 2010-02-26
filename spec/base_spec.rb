require File.join(File.dirname(__FILE__), 'spec_helper')

describe CommandT do
  describe 'regexp_for method' do
    it 'should insert globs before and after every character' do
      CommandT.regexp_for('foo').should == /.*(f).*(o).*(o).*/i
    end
  end
  describe 'matches_for method' do
    it 'should return empty array when source array empty' do
      @no_paths = CommandT.new
      @no_paths.matches_for('foo').should == []
      @no_paths.matches_for('').should == []
    end

    it 'should return empty array when no matches' do
      @no_matches = CommandT.new './foo', './bar'
      @no_matches.matches_for('xyz').should == []
    end

    it 'should return matching paths' do
      @foo_paths = CommandT.new './foo/bar', './foo/baz', './bing'
      @foo_paths.matches_for('z').should == ['./foo/baz']
      @foo_paths.matches_for('bg').should == ['./bing']
    end
  end
end
