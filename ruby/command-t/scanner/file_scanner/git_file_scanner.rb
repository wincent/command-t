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
require 'command-t/scanner/file_scanner'
require 'open3'

module CommandT
  class FileScanner
    # Uses git ls-files to scan for files
    class GitFileScanner < FindFileScanner
      class GitUnavailable < RuntimeError; end

      def paths
        pwd = Dir.pwd
        @paths[@path] ||= begin
          prepare_paths

          Dir.chdir(@path)
          command = "git ls-files --exclude-standard "
          stdin, stdout, stderr = Open3.popen3(*[
            "git",
            "ls-files",
            "--exclude-standard",
            @path
          ])

          set_wild_ignore(@wild_ignore)
          all_files = stdout.readlines.
            map { |x| x.chomp }.
            select { |x| not path_excluded?(x, prefix_len = 0) }.
            take(@max_files).
            to_a

          if err = stderr.gets
            raise GitUnavailable
          end

          all_files
        rescue GitUnavailable
          # git not available, fall back to find
          super
        ensure
          Dir.chdir(pwd)
        end
      end
    end # class GitFileScanner
  end # class FileScanner
end # module CommandT
