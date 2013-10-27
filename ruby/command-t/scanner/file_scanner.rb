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

require 'command-t/vim'
require 'command-t/scanner'

module CommandT
  # Reads the current directory recursively for the paths to all regular files.
  class FileScanner < Scanner
    attr_accessor :path

    def initialize path = Dir.pwd, options = {}
      @paths                = {}
      @paths_keys           = []
      @path                 = path
      @max_files            = options[:max_files] || 30_000
      @wild_ignore          = options[:wild_ignore]
      @base_wild_ignore     = VIM::wild_ignore
    end

    def paths
      return @paths[@path] if @paths.has_key?(@path)
      begin
        ensure_cache_under_limit
        @paths[@path] = []
        @depth        = 0
        @files        = 0
        @prefix_len   = @path.chomp('/').length
        set_wild_ignore(@wild_ignore)
        add_paths_for_directory @path, @paths[@path]
      rescue FileLimitExceeded
      ensure
        set_wild_ignore(@base_wild_ignore)
      end
      @paths[@path]
    end

    def flush
      @paths = {}
    end

  protected

    def path_excluded? path, prefix_len
      path = path[(prefix_len + 1)..-1]
      path = VIM::escape_for_single_quotes path
      ::VIM::evaluate("empty(expand(fnameescape('#{path}')))").to_i == 1
    end

    def set_wild_ignore(ignore)
      ::VIM::command("set wildignore=#{ignore}") if @wild_ignore
    end
  end # class FileScanner
end # module CommandT
