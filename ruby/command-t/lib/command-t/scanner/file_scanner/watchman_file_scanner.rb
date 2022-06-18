# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'pathname'
require 'socket'

module CommandT
  class Scanner
    class FileScanner
      # A FileScanner which delegates the heavy lifting to Watchman
      # (https://github.com/facebook/watchman); useful for very large hierarchies.
      #
      # Inherits from FindFileScanner so that it can fall back to it in the event
      # that Watchman isn't available or able to fulfil the request.
      class WatchmanFileScanner < FindFileScanner
        # Exception raised when Watchman is unavailable or unable to process the
        # requested path.
        WatchmanError = Class.new(::RuntimeError)

        def paths!
          sockname = extract_value(
            Watchman::Utils.load(get_raw_sockname),
            'sockname'
          )

          UNIXSocket.open(sockname) do |socket|
            root = Pathname.new(@path).realpath.to_s
            # Use `watch-project` for efficiency if available.
            if use_watch_project?
                result = Watchman::Utils.query(['watch-project', root], socket)
                root = extract_value(result, 'watch')
                relative_root = extract_value(result, 'relative_path') if result.has_key?('relative_path')
            else
              roots = Watchman::Utils.query(['watch-list'], socket)['roots']
              if !roots.include?(root)
                # This path isn't being watched yet; try to set up watch.
                result = Watchman::Utils.query(['watch', root], socket)

                # `root_restrict_files` setting may prevent Watchman from
                # working or enforce_root_files/root_files (>= version 3.1).
                extract_value(result)
              end
            end

            query_params = {
              'expression' => ['type', 'f'],
              'fields'     => ['name'],
            }
            query_params['relative_root'] = relative_root if relative_root
            query = ['query', root, query_params]
            paths = Watchman::Utils.query(query, socket)

            # could return error if watch is removed
            extracted = extract_value(paths, 'files')
            if @wildignore
              extracted.select { |path| path !~ @wildignore }
            else
              extracted
            end
          end
        rescue Errno::ENOENT, WatchmanError
          # watchman executable not present, or unable to fulfil request
          super
        end

      private

        def extract_value(object, key = nil)
          raise WatchmanError, object['error'] if object.has_key?('error')
          object[key]
        end

        def get_raw_sockname
          raw_sockname = %x{watchman --output-encoding=bser get-sockname}
          if $?.exitstatus.nil? || !$?.exitstatus&.zero?
            raise WatchmanError, 'get-sockname failed'
          end
          raw_sockname
        end

        # `watch_project` is available in 3.1+ but it's awkward to use without
        # `relative_root` (3.3+), so use the latter as our minimum version.
        def use_watch_project?
          return @use_watch_project if defined?(@use_watch_project)
          version = %x{watchman --version 2>/dev/null}
          major, minor = version.split('.')[0..1] if !$?.exitstatus.nil? && $?.exitstatus.zero? && version
          @use_watch_project = major.to_i > 3 || (major.to_i == 3 && minor.to_i >= 3)
        end
      end
    end
  end
end
