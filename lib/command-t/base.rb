module CommandT
  class Base
    def initialize path = Dir.pwd
      @scanner = Scanner.scanner path
      @matcher = Matcher.new @scanner
    end

    # Options:
    #   :limit (integer): limit the number of returned matches
    def sorted_matches_for str, options = {}
      @matcher.sorted_matches_for str, options
    end

    def flush
      @scanner.flush
    end

    def path= path
      @scanner.path = path
    end
  end # class Base
end # CommandT
