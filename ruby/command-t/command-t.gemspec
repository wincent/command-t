Gem::Specification.new do |s|
  s.name = 'command-t'

  # see note in the Rakefile about how intermediate version numbers
  # can break RubyGems
  s.version = `git describe --abbrev=0`.chomp

  s.authors = ['Greg Hurrell']
  s.email = 'greg@hurrell.net'

  s.files =
    ['../../README.md', '../../LICENSE', '../../Gemfile', '../../Rakefile'] +
    `git ls-files -z ./bin ./ext ./lib ../../doc`.split("\x0")

  s.license = 'BSD'
  s.require_paths = ['lib', 'ruby']
  s.extensions = '/extconf.rb'

  s.executables = ['commandtd']

  s.has_rdoc = false
  s.homepage = 'https://github.com/wincent/command-t'

  s.summary = 'The Command-T plug-in for VIM.'

  s.description = <<-EOS
    Command-T provides a fast, intuitive mechanism for opening files with a
    minimal number of keystrokes. Its full functionality is only available when
    installed as a Vim plug-in, but it is also made available as a RubyGem so
    that other applications can make use of its searching algorithm.
  EOS
end
