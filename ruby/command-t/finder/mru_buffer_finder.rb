require 'command-t/ext' # CommandT::Matcher
require 'command-t/scanner/mru_buffer_scanner'
require 'command-t/finder'

module CommandT
  class MruBufferFinder < Finder
    # Override sorted_matches_for to prevent MRU ordered matches from being
    # ordered alphabetically.
    def sorted_matches_for str, options = {}
      (@matcher.matches_for str).first(options[:limit]).map { |match| match.to_s }
    end

    def initialize
      @scanner = MruBufferScanner.new
      @matcher = Matcher.new @scanner, :always_show_dot_files => true
    end
  end # class MruBufferFinder
end # CommandT
