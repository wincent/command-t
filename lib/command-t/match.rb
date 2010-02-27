module CommandT
  class Match
    attr_reader :match

    def initialize match
      @match = match
    end

    def score
      return @score unless @score.nil?
      return (@score = 0.0 if @match.nil?)
    end

    def to_s
      @str ||= @match[0]
    end
  end
end # module CommandT
