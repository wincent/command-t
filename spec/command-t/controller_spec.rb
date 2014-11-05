# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'spec_helper'

describe CommandT::Controller do
  describe 'accept selection' do
    let(:controller) { CommandT::Controller.new }

    before do
      check_ruby_1_9_2
      stub_finder
      stub_match_window 'path/to/selection'
      stub_prompt
      stub_vim '/working/directory'
    end

    def set_string(name, value)
      stub(::VIM).evaluate(%{exists("#{name}")}).returns(1)
      stub(::VIM).evaluate(name).returns(value)
    end

    it 'opens relative paths inside the working directory' do
      stub(::VIM).evaluate('a:arg').returns('')
      set_string('g:CommandTTraverseSCM', 'pwd')
      controller.show_file_finder
      mock(::VIM).command('silent e path/to/selection')
      controller.accept_selection
    end

    it 'opens absolute paths outside the working directory' do
      stub(::VIM).evaluate('a:arg').returns('../outside')
      controller.show_file_finder
      mock(::VIM).command('silent e /working/outside/path/to/selection')
      controller.accept_selection
    end

    it 'does not get confused by common directory prefixes' do
      stub(::VIM).evaluate('a:arg').returns('../directory-oops')
      controller.show_file_finder
      mock(::VIM).command('silent e /working/directory-oops/path/to/selection')
      controller.accept_selection
    end
  end

  def check_ruby_1_9_2
    if RUBY_VERSION =~ /\A1\.9\.2/
      pending 'broken in Ruby 1.9.2 (see https://gist.github.com/455547)'
    end
  end

  def stub_finder(sorted_matches=[])
    finder = CommandT::Finder::FileFinder.new
    stub(finder).path = anything
    stub(finder).sorted_matches_for(anything, anything).returns(sorted_matches)
    stub(CommandT::Finder::FileFinder).new.returns(finder)
  end

  def stub_match_window(selection)
    match_window = Object.new
    stub(match_window).matches = anything
    stub(match_window).leave
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
    stub(::VIM).command(/augroup/)
    stub(::VIM).command('au!')
    stub(::VIM).command(/autocmd/)
    stub(::VIM).evaluate(/exists\(.+\)/).returns('0')
    stub(::VIM).evaluate('getcwd()').returns(working_directory)
    stub(::VIM).evaluate('&buflisted').returns('1')
    stub(::VIM).evaluate('&lines').returns('80')
    stub(::VIM).evaluate('&term').returns('vt100')
  end
end
