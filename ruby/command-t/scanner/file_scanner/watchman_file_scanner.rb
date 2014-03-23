# Copyright 2014 Wincent Colaiuta. All rights reserved.
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

require 'pathname'
require 'socket'
require 'command-t/vim'
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

      def paths
        @paths[@path] ||= begin
          ensure_cache_under_limit
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

            @paths[@path] = paths['files']
          end
        end

        @paths[@path]
      rescue Errno::ENOENT, WatchmanUnavailable
        # watchman executable not present, or unable to fulfil request
        super
      end
    end # class WatchmanFileScanner
  end # class FileScanner
end # module CommandT
