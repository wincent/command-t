# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class HistoryScanner < Scanner
      def initialize(history_command)
        @history_command = history_command
      end

      def paths
        @paths ||= paths!
      end

    private

      def paths!
        VIM.capture(@history_command).split("\n")[2..-1].map do |line|
          line.sub(/\A>?\s*\d+\s*(.+)/, '\1').strip
        end.uniq
      end
    end
  end
end
