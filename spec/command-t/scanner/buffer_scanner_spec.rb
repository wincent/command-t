# Copyright 2010-2013 Wincent Colaiuta. All rights reserved.
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

require 'spec_helper'
require 'ostruct'
require 'command-t/scanner/buffer_scanner'

describe CommandT::BufferScanner do
  def buffer name
    b = OpenStruct.new
    b.name = name
    b
  end

  before do
    @paths = %w(bar/abc bar/xyz baz bing foo/alpha/t1 foo/alpha/t2 foo/beta)
    @scanner = CommandT::BufferScanner.new
    stub(@scanner).relative_path_under_working_directory(is_a(String)) { |arg| arg }
    stub(::VIM::Buffer).count { 7 }
    (0..6).each do |n|
      stub(::VIM::Buffer)[n].returns(buffer @paths[n])
    end
  end

  describe 'paths method' do
    it 'returns a list of regular files' do
      @scanner.paths.should =~ @paths
    end
  end
end
