module CommandT
  class Base
    def initialize path = Dir.pwd
      @scanner = Scanner.scanner path
      @matcher = Matcher.new *@scanner.paths
    end

    # TODO: add :limit => 50
    # when no search string ret in alph order
    # when search string ret in score order
    def matches_for str
      @matcher.matches_for str
    end

    def path= path
      @scanner.path = path
    end
  end # class Base
end # CommandT
