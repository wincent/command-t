require File.join(File.dirname(__FILE__), '..', '..', 'spec_helper')

describe CommandT::Scanner::Find do
  before :all do
    dir = File.join(File.dirname(__FILE__), '..', '..', '..', 'fixtures')
    @scanner = CommandT::Scanner::Find.new dir
  end

  describe 'paths method' do
    it 'should return a list of regular files' do
      @scanner.paths.should == ['./bar/abc', './bar/xyz', './baz', './bing',
        './foo/alpha/t1', './foo/alpha/t2', './foo/beta']
    end
  end

  describe 'flush method' do
    it 'should force a rescan on next call to paths method' do
      first = @scanner.paths
      @scanner.flush
      @scanner.paths.object_id.should_not == first.object_id
    end
  end
end
