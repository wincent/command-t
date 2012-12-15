# Copyright 2010-2011 Wincent Colaiuta. All rights reserved.
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

require 'command-t/vim'
require 'command-t/scanner'

module CommandT
  # Reads the current directory recursively for the paths to all regular files.
  class GtagScanner < Scanner

    attr_accessor :path
    attr_accessor :buffer
    attr_accessor :buffer_name

    def initialize path = Dir.pwd, options = {}
      @paths                = {}
      @paths_keys           = []
      @path                 = path
      @max_caches           = options[:max_caches] || 1

      @buffer               = false
      @buffer_name          = nil
      @cached_buffer_name   = nil
      @buffer_cache         = nil
    end

    def paths
      if @buffer
        return @buffer_cache if @cached_buffer_name == @buffer_name
        @cached_buffer_name = @buffer_name
        @buffer_cache = get_result "global -f #{@buffer_name} | awk '{print $1, $2, \"|\" ,$4,$5,$6,$7,$8,$9,$10}'"
      else
        return @paths[@path] if @paths.has_key?(@path)
        ensure_cache_under_limit
        @paths[@path] = get_result "global -dt . | awk '{print $1,$3,$2}'"
      end
    end

    def flush
      `global -u`
      @paths = {}
      @paths_keys = []
      @cached_buffer_name = nil
    end

  private

    def ensure_cache_under_limit
      # Ruby 1.8 doesn't have an ordered hash, so use a separate stack to
      # track and expire the oldest entry in the cache
      if @max_caches > 0 && @paths_keys.length >= @max_caches
        @paths.delete @paths_keys.shift
      end
      @paths_keys << @path
    end

    def get_result cmd
      begin
        `#{cmd}`.lines.map do |line|
          line.strip
        end
      rescue
        []
      end
    end
  end # class FileScanner
end # module CommandT
