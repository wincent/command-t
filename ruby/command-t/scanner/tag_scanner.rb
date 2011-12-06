# Copyright 2011 Wincent Colaiuta. All rights reserved.
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
require 'command-t/vim/path_utilities'
require 'command-t/scanner'

module CommandT
  class TagScanner < Scanner
    include VIM::PathUtilities

    def paths
      tokens = Array.new
      
      tag_filenames.each { |tagfile|
        if FileTest.exist?(tagfile)
          File.open(tagfile).each { |line|
            # Don't want comments
            data = line.split if line.match(/^[^!]/)
              
            if data
              if include_filenames
                identifier = data[0] + ":" + data[1]
              else
                identifier = data[0]
              end
              tokens.push identifier
            end
          }
        end
      }
      
      tokens.sort.uniq
    end

    def tag_filenames
      tags = VIM::capture("silent set tags?")
      tags = tags[5,tags.length].split(',')
    end

    def include_filenames
      ::VIM::evaluate("g:command_t_tag_include_filenames").to_i != 0
    end
  end # class TagScanner
end # module CommandT
