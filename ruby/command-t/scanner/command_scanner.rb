# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class CommandScanner < Scanner
      def paths
        @paths ||= paths!
      end

    private

      def paths!
        VIM.capture('silent command').split("\n")[2..-1].map do |line|
          line.sub(/\A.{4}(\S+).+/, '\1')
        end

        # TODO: merge with built-in commands (via rtp snooping)
      end
    end # class CommandScanner
  end # class Scanner
end # module CommandT
