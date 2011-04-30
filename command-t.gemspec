Gem::Specification.new do |s|
  s.name = "command-t"

  # see note in the Rakefile about how intermediate version numbers
  # can break RubyGems
  v = `git describe --abbrev=0`.chomp
  s.version = v

  s.authors = ["Wincent Colaiuta"]
  s.date = "2011-01-05"
  s.email = "win@wincent.com"

  files =
    ["README.txt", "LICENSE", "Gemfile", "Rakefile"] +
    Dir.glob("{ruby,doc,plugin}/**/*")

  files = files.reject { |f| f =~ /\.(rbc|o|log|plist|dSYM)/ }

  s.files = files
  s.require_path = "ruby"
  s.extensions = "ruby/command-t/extconf.rb"

  s.executables = []

  s.has_rdoc = false
  s.homepage = "https://wincent.com/products/command-t"

  s.summary = "The Command-T plug-in for VIM."

  s.description = <<-EOS
    The Command-T plug-in provides an extremely fast, intuitive mechanism for
    opening files with a minimal number of keystrokes. It's named "Command-T"
    because it is inspired by the "Go to File" window bound to Command-T in
    TextMate.

    Files are selected by typing characters that appear in their paths, and are
    ordered by an algorithm which knows that characters that appear in certain
    locations (for example, immediately after a path separator) should be given
    more weight.

    To search efficiently, especially in large projects, you should adopt a
    "path-centric" rather than a "filename-centric" mentality. That is you
    should think more about where the desired file is found rather than what it
    is called. This means narrowing your search down by including some
    characters from the upper path components rather than just entering
    characters from the filename itself.

    The full functionality of Command-T is only available when installed as a
    Vim plug-in, but it is also made available as a RubyGem so that other
    applications can make use of the searching algorithm.
  EOS

end
