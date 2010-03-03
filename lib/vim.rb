require 'vim/screen'
require 'vim/window'

module VIM
  def self.has_syntax?
    VIM.evaluate('has("syntax")') != '0'
  end

  def self.pwd
    VIM.evaluate('getcwd()')
  end

  # Escape a string for safe inclusion in a Vim single-quoted string
  # (single quotes escaped by doubling, everything else is literal)
  def self.escape_for_single_quotes str
    str.gsub "'", "''"
  end
end # module VIM
