# Copyright 2010-2014 Wincent Colaiuta. All rights reserved.
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
  #
  # This is an abstract superclass; the real work is done by subclasses which
  # obtain file listings via different strategies (for examples, see the
  # RubyFileScanner and FindFileScanner subclasses).
  class FileScanner < Scanner
    class FileLimitExceeded < ::RuntimeError; end
    attr_accessor :path

    def initialize(path = Dir.pwd, options = {})
      @paths                = {}
      @paths_keys           = []
      @path                 = path
      @max_depth            = options[:max_depth] || 15
      @max_files            = options[:max_files] || 30_000
      @max_caches           = options[:max_caches] || 1
      @scan_dot_directories = options[:scan_dot_directories] || false
      @wild_ignore          = options[:wild_ignore]
      @base_wild_ignore     = VIM::wild_ignore
    end

    def paths
      @paths[@path] || begin
        ensure_cache_under_limit
        @prefix_len = @path.chomp('/').length
        nil
      end
    end

    def flush
      @paths = {}
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

    def path_excluded?(path)
      # first strip common prefix (@path) from path to match VIM's behavior
      path = path[(@prefix_len + 1)..-1]
      path = VIM::escape_for_single_quotes path
      ::VIM::evaluate("empty(expand(fnameescape('#{path}')))").to_i == 1
    end

    def set_wild_ignore(ignore)
      ::VIM::command("set wildignore=#{ignore}") if @wild_ignore
    end
  end # class FileScanner
end # module CommandT
