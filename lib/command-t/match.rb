module CommandT
  class Match
    attr_reader :offsets

    def initialize str, abbrev
      @str      = str
      @offsets  = []
      str       = str.downcase    # perform case-insensitive comparison
      abbrev    = abbrev.downcase # perform case-insensitive comparison
      cursor    = 0
      abbrev.each_char do |char|
        idx = str.index char, cursor
        if idx
          @offsets << idx
          cursor = idx + 1
        else
          @offsets = nil
          return
        end
      end
    end

    def matches?
      !@offsets.nil?
    end

    # Return a normalized score ranging from 0.0 to 1.0 indicating the
    # relevance of the match. The algorithm is specialized to provide
    # intuitive scores specifically for filesystem paths.
    #
    # 0.0 means the search string didn't match at all.
    #
    # 1.0 means the search string is a perfect (letter-for-letter) match.
    #
    # Scores will tend closer to 1.0 as:
    #
    #   - the number of matched characters increases
    #   - matched characters appear closer to the start of the nearest
    #     path component
    #   - matched characters appear immediately after special "boundary"
    #     characters such as "/", "_", "-", "." and " "
    #   - matched characters are uppercase letters immediately after
    #     lowercase letters of numbers
    #   - matched characters are lowercase letters immediately after
    #     numbers
    def score
      return @score unless @score.nil?
      return (@score = 0.0) if @offsets.nil? || @offsets.empty?
      len = @str.length
      return (@score = 1.0) if @offsets.length == len
      @score = 0.0
      max_score_per_char = 1.0 / @offsets.length
      for i in 0..(@offsets.length - 1) do
        score_for_char = max_score_per_char
        offset = @offsets[i]
        if offset > 0
          factor = nil
          case @str[offset - 1, 1]
          when '/'
            factor = 0.9
          when '-', '_', ' ', '0'..'9'
            factor = 0.8
          when '.'
            factor = 0.7
          when 'a'..'z'
            if @str[offset, 1] =~ /[A-Z]/
              factor = 0.8
            end
          end
          if factor.nil?
            # factor falls the farther we are from last matched char
            if i > 1
              distance = offset - @offsets[i - 1]
              factor = 1.0 / distance
            else
              factor = 1.0 / (offset + 1)
            end
          end
          score_for_char *= factor
        end
        @score += score_for_char
      end
      @score
    end

    def to_s
      @str
    end
  end
end # module CommandT
