# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require File.join(File.dirname(__FILE__), '..', 'spec_helper')
require 'command-t/finder'

describe CommandT::Finder do
  before :all do
    @finder = CommandT::Finder.new File.join(File.dirname(__FILE__), '..',
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

  describe 'sorted_matches_for method' do
    it 'should return an empty array when no matches' do
      @finder.sorted_matches_for('kung foo fighting').should == []
    end

    it 'should return all files when query string is empty' do
      @finder.sorted_matches_for('').should == @all_fixtures
    end

    it 'should return files in alphabetical order when query string is empty' do
      results = @finder.sorted_matches_for('')
      results.should == results.sort
    end

    it 'should return matching files in score order' do
      @finder.sorted_matches_for('ba').should == ['bar/abc', 'bar/xyz', 'baz',
        'foo/beta']
      @finder.sorted_matches_for('a').should == ['foo/alpha/t1',
        'foo/alpha/t2', 'bar/abc', 'bar/xyz', 'baz', 'foo/beta']
    end

    it 'should obey the :limit option for empty search strings' do
      @finder.sorted_matches_for('', :limit => 2).should == ['bar/abc',
        'bar/xyz']
    end

    it 'should obey the :limit option for non-empty search strings' do
      @finder.sorted_matches_for('a', :limit => 3).should == ['foo/alpha/t1',
        'foo/alpha/t2', 'bar/abc']
    end
  end
end
