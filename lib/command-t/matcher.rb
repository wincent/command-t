module CommandT
  class Matcher
    # Turn a search string like:
    #
    #   foo
    #
    # Into a regular expression like:
    #
    #   /\A.*?(f).*?(o).*?(o).*?\z/i
    #
    # We use capturing parentheses so that we can look at the offsets in the
    # match data and assign a score based on the position within the string.
    #
    # We use non-greedy globs so that higher scoring matches (further to the
    # left) will be selected if they exist.
    #
    # For empty search strings we just return /.*/ so as to slurp up the entire
    # string.
    def self.regexp_for str
      raise ArgumentError.new('nil str') if str.nil?
      return /.*/ if str.empty?
      chars = str.chars.map { |c| '(' + Regexp.escape(c) + ')' }
      glob = '.*?'
      Regexp.new('\A' + glob + (chars.join glob) + glob + '\z',
        Regexp::IGNORECASE)
    end

    def initialize scanner
      raise ArgumentError.new('nil scanner') if scanner.nil?
      @scanner = scanner
    end

    # Unlike the matches_for method, sorted_matches_for returns an
    # array of String objects, seeing as the score information embedded
    # in the Match class isn't required after sorting.
    def sorted_matches_for str, options = {}
      matches = matches_for str
      unless str.empty? # override alphabetical sorting
        matches = matches.sort do |a, b|
          comp = (a.score <=> b.score) * -1
          if comp == 0
            comp = (a.to_s <=> b.to_s)
          end
          comp
        end
      end
      limit = options[:limit] || 0
      if matches.length < limit or limit == 0
        return matches.map { |m| m.to_s }
      end
      matches[0..limit-1].map { |m| m.to_s }
    end

    # Returns an array of Match objects.
    def matches_for str
      raise ArgumentError.new('nil str') if str.nil?
      regexp = self.class.regexp_for str
      matches = []
      @scanner.paths.each do |path|
        match = Match.match path, regexp
        matches << match unless match.nil?
      end
      matches
    end
  end # class Matcher
end # module CommandT
