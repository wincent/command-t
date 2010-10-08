require 'spec_helper'
require 'command-t/controller'

module VIM; end

describe CommandT::Controller do
  describe 'accept selection' do
    before do
      stub_finder
      stub_match_window 'path/to/selection'
      stub_prompt
      stub_vim '/working/directory'
    end

    before do
      @controller = CommandT::Controller.new
    end

    it 'opens relative paths inside the working directory' do
      stub(::VIM).evaluate('a:arg').returns('')
      @controller.show
      mock(::VIM).command('silent e path/to/selection')
      @controller.accept_selection
    end

    it 'opens absolute paths outside the working directory' do
      stub(::VIM).evaluate('a:arg').returns('../outside')
      @controller.show
      mock(::VIM).command('silent e /working/outside/path/to/selection')
      @controller.accept_selection
    end

    it 'does not get confused by common directory prefixes' do
      stub(::VIM).evaluate('a:arg').returns('../directory-oops')
      @controller.show
      mock(::VIM).command('silent e /working/directory-oops/path/to/selection')
      @controller.accept_selection
    end
  end

  private

  def stub_finder(sorted_matches=[])
    finder = Object.new
    stub(finder).path = anything
    stub(finder).sorted_matches_for(anything, anything).returns(sorted_matches)
    stub(CommandT::Finder).new.returns(finder)
  end

  def stub_match_window(selection)
    match_window = Object.new
    stub(match_window).matches = anything
    stub(match_window).close
    stub(match_window).selection.returns(selection)
    stub(CommandT::MatchWindow).new.returns(match_window)
  end

  def stub_prompt(abbrev='')
    prompt = Object.new
    stub(prompt).focus
    stub(prompt).clear!
    stub(prompt).abbrev.returns(abbrev)
    stub(CommandT::Prompt).new.returns(prompt)
  end

  def stub_vim(working_directory)
    stub($curbuf).number.returns('0')
    stub(::VIM).command(/noremap/)
    stub(::VIM).command('silent b 0')
    stub(::VIM).evaluate(/exists\(.+\)/).returns('0')
    stub(::VIM).evaluate('getcwd()').returns(working_directory)
    stub(::VIM).evaluate('&buflisted').returns('1')
    stub(::VIM).evaluate('&lines').returns('80')
    stub(::VIM).evaluate('&term').returns('vt100')
  end
end
