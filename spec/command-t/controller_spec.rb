# Copyright 2010-present Greg Hurrell. All rights reserved.
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
      allow(::VIM).to receive(:evaluate).with(%{exists("#{name}")}).and_return(1)
      allow(::VIM).to receive(:evaluate).with(name).and_return(value)
    end

    it 'opens relative paths inside the working directory' do
      allow(::VIM).to receive(:evaluate).with('a:arg').and_return('')
      set_string('g:CommandTTraverseSCM', 'pwd')
      controller.show_file_finder
      expect(::VIM).to receive(:command).with('silent CommandTOpen edit path/to/selection')
      controller.accept_selection
    end

    it 'opens absolute paths outside the working directory' do
      allow(::VIM).to receive(:evaluate).with('a:arg').and_return('../outside')
      controller.show_file_finder
      expect(::VIM).to receive(:command).with('silent CommandTOpen edit /working/outside/path/to/selection')
      controller.accept_selection
    end

    it 'does not get confused by common directory prefixes' do
      allow(::VIM).to receive(:evaluate).with('a:arg').and_return('../directory-oops')
      controller.show_file_finder
      expect(::VIM).to receive(:command).with('silent CommandTOpen edit /working/directory-oops/path/to/selection')
      controller.accept_selection
    end

    it 'does not enter an infinite loop when toggling focus' do
      # https://github.com/wincent/command-t/issues/157
      allow(::VIM).to receive(:evaluate).with('a:arg').and_return('')
      set_string('g:CommandTTraverseSCM', 'pwd')
      controller.show_file_finder
      expect { controller.toggle_focus }.to_not raise_error
    end
  end

  def check_ruby_1_9_2
    if RUBY_VERSION =~ /\A1\.9\.2/
      pending 'broken in Ruby 1.9.2 (see https://gist.github.com/455547)'
    end
  end

  def stub_finder(sorted_matches=[])
    finder = CommandT::Finder::FileFinder.new
    allow(finder).to receive(:"path=").with(anything)
    allow(finder).to receive(:sorted_matches_for).with(anything, anything).and_return(sorted_matches)
    allow(CommandT::Finder::FileFinder).to receive(:new).and_return(finder)
  end

  def stub_match_window(selection)
    match_window = Object.new
    allow(match_window).to receive(:"matches=").with(anything)
    allow(match_window).to receive(:leave)
    allow(match_window).to receive(:focus)
    allow(match_window).to receive(:selection).and_return(selection)
    allow(CommandT::MatchWindow).to receive(:new).and_return(match_window)
  end

  def stub_prompt(abbrev='')
    prompt = Object.new
    allow(prompt).to receive(:focus)
    allow(prompt).to receive(:unfocus)
    allow(prompt).to receive(:clear!)
    allow(prompt).to receive(:redraw)
    allow(prompt).to receive(:abbrev).and_return(abbrev)
    allow(CommandT::Prompt).to receive(:new).and_return(prompt)
  end

  def stub_vim(working_directory)
    allow($curbuf).to receive(:number).and_return('0')
    allow(::VIM).to receive(:command).with(/noremap/)
    allow(::VIM).to receive(:command).with('silent b 0')
    allow(::VIM).to receive(:command).with(/augroup/)
    allow(::VIM).to receive(:command).with('au!')
    allow(::VIM).to receive(:command).with(/autocmd/)
    allow(::VIM).to receive(:evaluate).with(/exists\(.+\)/).and_return('0')
    allow(::VIM).to receive(:evaluate).with('getcwd()').and_return(working_directory)
    allow(::VIM).to receive(:evaluate).with('&buflisted').and_return('1')
    allow(::VIM).to receive(:evaluate).with('&lines').and_return('80')
    allow(::VIM).to receive(:evaluate).with('&term').and_return('vt100')
    allow(::VIM).to receive(:evaluate).with("fnameescape('#{working_directory}-oops/path/to/selection')").and_return("#{working_directory}-oops/path/to/selection")
    allow(::VIM).to receive(:evaluate).with("fnameescape('path/to/selection')").and_return('path/to/selection')
    allow(::VIM).to receive(:evaluate).with("fnameescape('/working/outside/path/to/selection')").and_return('/working/outside/path/to/selection')
    allow(::VIM).to receive(:evaluate).with('v:version').and_return(704)
    allow(::VIM).to receive(:evaluate).with('!&buflisted && &buftype == "nofile"')
  end
end
