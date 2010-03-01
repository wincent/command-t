module CommandT
  class Matcher
    attr_accessor :paths

    # Turn a search string like:
    #   foo
    # Into a regular expression like:
    #   /\A.*?(f).*?(o).*?(o).*?\z/i
    def self.regexp_for str
      raise ArgumentError.new('nil str') if str.nil?
      return /.*/ if str.empty?
      chars = str.chars.map { |c| '(' + Regexp.escape(c) + ')' }
      glob = '.*?'
      Regexp.new('\A' + glob + (chars.join glob) + glob + '\z',
        Regexp::IGNORECASE)
    end

    def initialize *paths
      @paths = paths
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
      @paths.each do |path|
        match = path.match(regexp)
        matches << Match.new(match) unless match.nil?
      end
      matches
    end
  end # class Matcher
end # module CommandT
