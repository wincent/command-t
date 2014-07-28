# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

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

    def prepare_paths
      ensure_cache_under_limit
      @prefix_len = @path.chomp('/').length
    end

    def paths
      @paths[@path] || begin
        prepare_paths
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

    def path_excluded?(path, prefix_len = @prefix_len)
      # if there is no wild_ignore, skip the call to evaluate which can be
      # expensive for large file lists
      if @wild_ignore && !@wild_ignore.empty?
        # first strip common prefix (@path) from path to match VIM's behavior
        path = path[(prefix_len + 1)..-1]
        path = VIM::escape_for_single_quotes path
        ::VIM::evaluate("empty(expand(fnameescape('#{path}')))").to_i == 1
      end
    end

    def set_wild_ignore(ignore)
      ::VIM::command("set wildignore=#{ignore}") if @wild_ignore
    end
  end # class FileScanner
end # module CommandT
