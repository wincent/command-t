# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    # Reads the current directory recursively for the paths to all regular files.
    #
    # This is an abstract superclass; the real work is done by subclasses which
    # obtain file listings via different strategies (for examples, see the
    # RubyFileScanner and FindFileScanner subclasses).
    class FileScanner < Scanner
      # Subclasses
      autoload :CmdFileScanner,      'command-t/scanner/file_scanner/cmd_file_scanner'
      autoload :FindFileScanner,     'command-t/scanner/file_scanner/find_file_scanner'
      autoload :GitFileScanner,      'command-t/scanner/file_scanner/git_file_scanner'
      autoload :RubyFileScanner,     'command-t/scanner/file_scanner/ruby_file_scanner'
      autoload :WatchmanFileScanner, 'command-t/scanner/file_scanner/watchman_file_scanner'

      def self.for_scanner_type s
        case s
        when 'ruby', nil # ruby is the default
          RubyFileScanner
        when 'find'
          FindFileScanner
        when 'watchman'
          WatchmanFileScanner
        when 'git'
          GitFileScanner
        when 'cmd'
          CmdFileScanner
        else
          raise ArgumentError, "unknown scanner type #{s.inspect}"
        end
      end

      attr_accessor :path

      def initialize(path = Dir.pwd, options = {})
        @paths                = {}
        @paths_keys           = []
        @path                 = path
        @max_depth            = options[:max_depth] || 15
        @max_files            = options[:max_files] || 100_000
        @max_caches           = options[:max_caches] || 1
        @scan_dot_directories = options[:scan_dot_directories] || false
        @wildignore           = options[:wildignore]
        @scan_submodules      = options[:git_scan_submodules] || false
        @include_untracked    = options[:git_include_untracked] || false
      end

      def paths
        @paths[@path] ||= begin
          ensure_cache_under_limit
          @prefix_len = @path.chomp('/').length + 1
          paths!
        end
      end

      def flush
        @paths = {}
      end

    private

      def show_max_files_warning
        unless VIM::get_bool('g:CommandTSuppressMaxFilesWarning', false)
          ::VIM::command('redraw!')
          ::VIM::command('echohl ErrorMsg')
          warning =
            "Warning: maximum file limit reached\n" +
            "\n" +
            "Increase it by setting a higher value in $MYVIMRC; eg:\n" +
            "  let g:CommandTMaxFiles=#{@max_files * 2}\n" +
            "Or suppress this warning by setting:\n" +
            "  let g:CommandTSuppressMaxFilesWarning=1\n" +
            "For best performance, consider using a fast scanner; see:\n" +
            "  :help g:CommandTFileScanner\n" +
            "\n" +
            "Press ENTER to continue."
          ::VIM::evaluate(%{input("#{warning}")})
          ::VIM::command('echohl None')
        end
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

      def path_excluded?(path)
        if @wildignore
          path =~ @wildignore
        end
      end
    end
  end
end
