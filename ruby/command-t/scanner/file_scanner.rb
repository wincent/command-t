# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    # Reads the current directory recursively for the paths to all regular files.
    #
    # This is an abstract superclass; the real work is done by subclasses which
    # obtain file listings via different strategies (for examples, see the
    # RubyFileScanner and FindFileScanner subclasses).
    class FileScanner < Scanner
      # Errors
      autoload :FileLimitExceeded,   'command-t/scanner/file_scanner/file_limit_exceeded'

      # Subclasses
      autoload :FindFileScanner,     'command-t/scanner/file_scanner/find_file_scanner'
      autoload :GitFileScanner,      'command-t/scanner/file_scanner/git_file_scanner'
      autoload :RubyFileScanner,     'command-t/scanner/file_scanner/ruby_file_scanner'
      autoload :WatchmanFileScanner, 'command-t/scanner/file_scanner/watchman_file_scanner'

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
        @base_wild_ignore     = wild_ignore
      end

      def paths
        @paths[@path] ||= begin
          ensure_cache_under_limit
          @prefix_len = @path.chomp('/').length + 1
          set_wild_ignore { paths! }
        end
      end

      def flush
        @paths = {}
      end

    private

      def wild_ignore
        VIM::exists?('&wildignore') && ::VIM::evaluate('&wildignore').to_s
      end

      def paths!
        raise RuntimeError, 'Subclass responsibility'
      end

      def ensure_cache_under_limit
        # Ruby 1.8 doesn't have an ordered hash, so use a separate stack to
        # track and expire the oldest entry in the cache
        if @max_caches > 0 && @paths_keys.length >= @max_caches
          @paths.delete @paths_keys.shift
        end
        @paths_keys << @path
      end

      def path_excluded?(path, prefix_len = @prefix_len)
        if apply_wild_ignore?
          # first strip common prefix (@path) from path to match VIM's behavior
          path = path[prefix_len..-1]
          path = VIM::escape_for_single_quotes path
          ::VIM::evaluate("empty(expand(fnameescape('#{path}')))").to_i == 1
        end
      end

      def has_custom_wild_ignore?
        @wild_ignore && !@wild_ignore.empty?
      end

      # Used to skip expensive calls to `expand()` when there is no applicable
      # wildignore.
      def apply_wild_ignore?
        has_custom_wild_ignore? || @base_wild_ignore
      end

      def set_wild_ignore(&block)
        ::VIM::command("set wildignore=#{@wild_ignore}") if has_custom_wild_ignore?
        yield
      ensure
        ::VIM::command("set wildignore=#{@base_wild_ignore}") if has_custom_wild_ignore?
      end
    end # class FileScanner
  end # class Scanner
end # module CommandT
