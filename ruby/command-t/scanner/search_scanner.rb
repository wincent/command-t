# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class SearchScanner < Scanner
      def paths
        @searches ||= paths!
      end

    private

      def paths!
        VIM.capture('silent history /').split("\n")[2..-1].map do |line|
          line.sub(/\A>?\s*\d+\s*(.+)/, '\1')
        end
      end
    end # class SearchScanner
  end # class Scanner
end # module CommandT
