require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe CommandT::Scanner::Ruby do
  before do
    @dir = File.join(File.dirname(__FILE__), '..', '..', '..', 'fixtures')
    @scanner = CommandT::Scanner::Ruby.new @dir
  end

  describe 'paths method' do
    it 'should return a list of regular files' do
      @scanner.paths.should == ['bar/abc', 'bar/xyz', 'baz', 'bing',
        'foo/alpha/t1', 'foo/alpha/t2', 'foo/beta']
    end
  end

  describe 'flush method' do
    it 'should force a rescan on next call to paths method' do
      first = @scanner.paths
      @scanner.flush
      @scanner.paths.object_id.should_not == first.object_id
    end
  end

  describe 'path= method' do
    it 'should allow repeated applications of scanner at different paths' do
      @scanner.paths.should == ['bar/abc', 'bar/xyz', 'baz', 'bing',
        'foo/alpha/t1', 'foo/alpha/t2', 'foo/beta']

      # drill down 1 level
      @scanner.path = File.join(@dir, 'foo')
      @scanner.paths.should == ['alpha/t1', 'alpha/t2', 'beta']

      # and another
      @scanner.path = File.join(@dir, 'foo', 'alpha')
      @scanner.paths.should == ['t1', 't2']
    end
  end
end
