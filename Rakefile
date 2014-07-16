require 'yaml'

def bail_on_failure
  exitstatus = $?.exitstatus
  if exitstatus != 0
    err "last command failed with exit status #{exitstatus}"
    exit 1
  end
end

def version
  `git describe`.chomp
end

def rubygems_version
  # RubyGems will barf if we try to pass an intermediate version number
  # like "1.1b2-10-g61a374a", so no choice but to abbreviate it
  `git describe --abbrev=0`.chomp
end

def yellow
  "\033[33m"
end

def red
  "\033[31m"
end

def clear
  "\033[0m"
end

def warn str
  puts "#{yellow}warning: #{str}#{clear}"
end

def err str
  puts "#{red}error: #{str}#{clear}"
end

def prepare_release_notes
  # extract base release notes from README.txt HISTORY section
  File.open('.release-notes.txt', 'w') do |out|
    lines = File.readlines('README.txt').each { |line| line.chomp! }
    while line = lines.shift do
      next unless line =~ /^HISTORY +\*command-t-history\*$/
      break unless lines.shift == '' &&
                  (line = lines.shift) && line =~ /^\d\.\d/ &&
                  lines.shift == ''
      while line = lines.shift and line != ''
        out.puts line
      end
      break
    end
    out.puts ''
    out.puts '# Please edit the release notes to taste.'
    out.puts '# Blank lines and lines beginning with a hash will be removed.'
    out.puts '# To abort, exit your editor with a non-zero exit status (:cquit in Vim).'
  end

  unless system "$EDITOR .release-notes.txt"
    err "editor exited with non-zero exit status; aborting"
    exit 1
  end

  filtered = read_release_notes
  File.open('.release-notes.txt', 'w') do |out|
    out.print filtered
  end
end

def read_release_notes
  File.readlines('.release-notes.txt').reject do |line|
    line =~ /^(#.*|\s*)$/ # filter comment lines and blank lines
  end.join
end

task :default => :spec

desc 'Print help on preparing a release'
task :help do
  puts <<-END

The general release sequence is:

  rake prerelease
  rake gem
  rake push
  rake upload:all

Note: the upload task depends on the Mechanize gem; and may require a
prior `gem install mechanize`

  END
end

desc 'Run specs'
task :spec do
  system 'bundle exec rspec spec'
  bail_on_failure
end

desc 'Create vimball archive'
task :vimball => :check_tag do
  system 'make'
  bail_on_failure
  FileUtils.cp 'command-t.vba', "command-t-#{version}.vba"
end

desc 'Clean compiled products'
task :clean do
  Dir.chdir 'ruby/command-t' do
    system 'make clean' if File.exists?('Makefile')
    system 'rm -f Makefile'
  end
end

desc 'Clobber all generated files'
task :clobber => :clean do
  system 'make clean'
end

desc 'Compile extension'
task :make do
  Dir.chdir 'ruby/command-t' do
    ruby 'extconf.rb'
    system 'make clean'
    bail_on_failure
    system 'make'
    bail_on_failure
  end
end

namespace :make do
  desc 'Compile under all multiruby versions'
  task :all do
    system './compile-test.sh'
    bail_on_failure
  end
end

namespace :spec do
  desc 'Run specs under all multiruby versions'
  task :all do
    system './multi-spec.sh'
    bail_on_failure
  end
end

desc 'Check that the current HEAD is tagged'
task :check_tag do
  unless system 'git describe --exact-match HEAD 2> /dev/null'
    warn 'current HEAD is not tagged'
  end
end

desc 'Run checks prior to release'
task :prerelease => ['make:all', 'spec:all', :vimball, :check_tag]

namespace :upload do
  desc 'Upload current vimball to Amazon S3'
  task :s3 => :vimball do
    sh 'aws --curl-options=--insecure put ' +
      "s3.wincent.com/command-t/releases/command-t-#{version}.vba " +
      "command-t-#{version}.vba"
    sh 'aws --curl-options=--insecure put ' +
      "s3.wincent.com/command-t/releases/command-t-#{version}.vba?acl " +
      '--public'
  end

  desc 'Upload current vimball to www.vim.org'
  task :vim => :vimball do
    prepare_release_notes
    sh "vendor/vimscriptuploader/vimscriptuploader.rb \
            --id 3025 \
            --file command-t-#{version}.vba \
            --message-file .release-notes.txt \
            --version #{version} \
            --config ~/.vim_org.yml \
            .vim_org.yml"
  end

  desc 'Upload current vimball everywhere'
  task :all => [ :s3, :vim ]
end

desc 'Create the ruby gem package'
task :gem => :check_tag do
  sh "gem build command-t.gemspec"
end

desc 'Push gem to Gemcutter ("gem push")'
task :push => :gem do
  sh "gem push command-t-#{rubygems_version}.gem"
end
