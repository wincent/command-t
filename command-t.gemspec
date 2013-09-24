Gem::Specification.new do |s|
  s.name = 'command-t'

  # see note in the Rakefile about how intermediate version numbers
  # can break RubyGems
  v = `git describe --abbrev=0`.chomp
  s.version = v

  s.authors = ['Wincent Colaiuta']
  s.email = 'win@wincent.com'

  files =
    ['README.txt', 'LICENSE', 'Gemfile', 'Rakefile'] +
    Dir.glob('{ruby,doc,plugin}/**/*')

  files = files.reject { |f| f =~ /\.(rbc|o|log|plist|dSYM)/ }

  s.files = files
  s.require_path = 'ruby'
  s.extensions = 'ruby/command-t/extconf.rb'

  s.executables = []

  s.has_rdoc = false
  s.homepage = 'https://wincent.com/products/command-t'

  s.summary = 'The Command-T plug-in for VIM.'

  s.description = <<-EOS
    Command-T provides a fast, intuitive mechanism for opening files with a
    minimal number of keystrokes. Its full functionality is only available when
    installed as a Vim plug-in, but it is also made available as a RubyGem so
    that other applications can make use of its searching algorithm.
  EOS
end
