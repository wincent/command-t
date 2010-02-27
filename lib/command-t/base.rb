module CommandT
  class Base
    def initialize path = Dir.pwd
      @scanner = Scanner.scanner path
      @matcher = Matcher.new *@scanner.paths
    end

    def matches_for str
      @matcher.matches_for str
    end
  end # class Base
end # CommandT
