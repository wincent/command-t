module CommandT
  class Matcher
    def initialize scanner
      raise ArgumentError.new('nil scanner') if scanner.nil?
      @scanner = scanner
    end

    def sorted_matches_for abbrev, options = {}
      matches = matches_for abbrev
      unless abbrev.empty? # override alphabetical sorting
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
    def matches_for abbrev
      raise ArgumentError.new('nil abbrev') if abbrev.nil?
      matches = []
      @scanner.paths.each do |path|
        match = Match.new path, abbrev
        matches << match if match.matches?
      end
      matches
    end
  end # class Matcher
end # module CommandT
