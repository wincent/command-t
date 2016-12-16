require 'spec_helper'

describe CommandT::Scanner::FileScanner::CmdFileScanner do
  before do
    @dir = File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'fixtures')
    @dir = File.absolute_path @dir
    @options = {
      custom_cmd: 'pwd && echo bar',
    }

    @scanner = CommandT::Scanner::FileScanner::CmdFileScanner.new @dir, @options

    stub(::VIM).evaluate(/exists/) { 1 }
    stub(::VIM).evaluate(/expand\(.+\)/) { '0' }
    stub(::VIM).command(/echon/)
    stub(::VIM).command('redraw')
  end

  describe 'path= method' do
    it 'allows repeated applications of scanner at different paths' do
      result = [ @dir, 'bar' ]

      expect(@scanner.paths.to_a).to match_array(result)

      # drill down 1 level
      @scanner.path = File.join @dir, 'foo'
      result[0] = File.join @dir, 'foo'
      expect(@scanner.paths.to_a).to match_array(result)

      # and another
      @scanner.path = File.join @dir, 'foo', 'alpha'
      result[0] = File.join @dir, 'foo', 'alpha'
      expect(@scanner.paths.to_a).to match_array(result)
    end
  end
end
