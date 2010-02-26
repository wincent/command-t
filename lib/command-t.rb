class CommandT
  # Turn a search string like:
  #   "foo"
  # Into a regular expression like:
  #   /.*(f).*(o).*(o).*/i
  def self.regexp_for str
    chars = str.chars.map { |c| '(' + Regexp.escape(c) + ')' }
    glob = '.*'
    Regexp.new(glob + (chars.join glob) + glob, Regexp::IGNORECASE)
  end

  def initialize *paths
    @paths = paths
  end

  def matches_for str
    regexp = self.class.regexp_for str
    @paths.select do |path|
      !path.match(regexp).nil?
    end
  end
end # class CommandT
