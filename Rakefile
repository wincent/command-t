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

def warn(str)
  puts "#{yellow}warning: #{str}#{clear}"
end

def err(str)
  puts "#{red}error: #{str}#{clear}"
end

task :default => :help

desc 'Print help on preparing a release'
task :help do
  puts <<-END

The general release sequence is:

  rake prerelease
  rake gem
  rake push
  rake upload:all

For a full list of available tasks:

  rake -T

  END
end

desc 'Run specs'
task :spec do
  system 'bundle exec rspec spec'
  bail_on_failure
end

desc 'Create archive'
task :archive => :check_tag do
  system "git archive -o command-t-#{version}.zip HEAD -- ."
  bail_on_failure
end

desc 'Clean compiled products'
task :clean do
  Dir.chdir 'ruby/command-t/ext/command-t' do
    system 'make clean' if File.exists?('Makefile')
    system 'rm -f Makefile'
  end
end

desc 'Compile extension'
task :make do
  Dir.chdir 'ruby/command-t/ext/command-t' do
    ruby 'extconf.rb'
    system 'make clean'
    bail_on_failure
    system 'make'
    bail_on_failure
  end
end

desc 'Check that the current HEAD is tagged'
task :check_tag do
  unless system 'git describe --exact-match HEAD 2> /dev/null'
    warn 'current HEAD is not tagged'
  end
end

desc 'Verify that required dependencies are installed'
task :check_deps do
  begin
    require 'rubygems'
    require 'mechanize'
  rescue LoadError
    warn 'mechanize not installed (`gem install mechanize` in order to upload)'
  end
end

desc 'Run checks prior to release'
task :prerelease => [:make, :spec, :archive, :check_tag, :check_deps]

desc 'Prepare release notes from HISTORY'
task :notes do
  File.open('.release-notes.txt', 'w') do |out|
    lines = File.readlines('doc/command-t.txt').each(&:chomp!)
    while line = lines.shift do
      next unless line =~ /^HISTORY +\*command-t-history\*$/
      break unless lines.shift == '' &&
                  (line = lines.shift) && line =~ /^\d\.\d/ &&
                  lines.shift == ''
      while (line = lines.shift) && line != ''
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

  filtered = File.readlines('.release-notes.txt').reject do |line|
    line =~ /^(#.*|\s*)$/ # filter comment lines and blank lines
  end.join

  File.open('.release-notes.txt', 'w') do |out|
    out.print filtered
  end
end

namespace :upload do
  desc 'Upload current archive to Amazon S3'
  task :s3 => :archive do
    sh 'aws --curl-options=--insecure put ' +
      "s3.wincent.com/command-t/releases/command-t-#{version}.zip " +
      "command-t-#{version}.zip"
    sh 'aws --curl-options=--insecure put ' +
      "s3.wincent.com/command-t/releases/command-t-#{version}.zip?acl " +
      '--public'
  end

  desc 'Upload current archive to www.vim.org'
  task :vim => [:archive, :notes] do
    sh "vendor/vimscriptuploader/vimscriptuploader.rb \
            --id 3025 \
            --file command-t-#{version}.zip \
            --message-file .release-notes.txt \
            --version #{version} \
            --config ~/.vim_org.yml \
            .vim_org.yml"
  end

  desc 'Upload current archive everywhere'
  task :all => [:s3, :vim]
end

desc 'Create the ruby gem package'
task :gem => :check_tag do
  Dir.chdir 'ruby/command-t' do
    sh "gem build command-t.gemspec"
  end
end

desc 'Push gem to Gemcutter ("gem push")'
task :push => :gem do
  Dir.chdir 'ruby/command-t' do
    sh "gem push command-t-#{rubygems_version}.gem"
  end
end
