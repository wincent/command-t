# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'pathname'
require 'socket'
require 'command-t/vim/path_utilities'
require 'command-t/scanner/file_scanner'
require 'command-t/scanner/file_scanner/find_file_scanner'

module CommandT
  class FileScanner
    # A FileScanner which delegates the heavy lifting to Watchman
    # (https://github.com/facebook/watchman); useful for very large hierarchies.
    #
    # Inherits from FindFileScanner so that it can fall back to it in the event
    # that Watchman isn't available or able to fulfil the request.
    class WatchmanFileScanner < FindFileScanner
      # Exception raised when Watchman is unavailable or unable to process the
      # requested path.
      class WatchmanUnavailable < RuntimeError; end

      def paths!
        sockname = Watchman::Utils.load(
          %x{watchman --output-encoding=bser get-sockname}
        )['sockname']
        raise WatchmanUnavailable unless $?.exitstatus.zero?

        UNIXSocket.open(sockname) do |socket|
          root = Pathname.new(@path).realpath.to_s
          roots = Watchman::Utils.query(['watch-list'], socket)['roots']
          if !roots.include?(root)
            # this path isn't being watched yet; try to set up watch
            result = Watchman::Utils.query(['watch', root], socket)

            # root_restrict_files setting may prevent Watchman from working
            raise WatchmanUnavailable if result.has_key?('error')
          end

          query = ['query', root, {
            'expression' => ['type', 'f'],
            'fields'     => ['name'],
          }]
          paths = Watchman::Utils.query(query, socket)

          # could return error if watch is removed
          raise WatchmanUnavailable if paths.has_key?('error')

          paths['files']
        end
      end
    rescue Errno::ENOENT, WatchmanUnavailable
      # watchman executable not present, or unable to fulfil request
      super
    end # class WatchmanFileScanner
  end # class FileScanner
end # module CommandT
