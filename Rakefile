require 'yaml'

def bail_on_failure
  exitstatus = $?.exitstatus
  if exitstatus != 0
    raise "last command failed with exit status #{exitstatus}"
  end
end

def version
  `git describe`.chomp
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
end

def read_release_notes
  File.readlines('.release-notes.txt').reject do |line|
    line =~ /^(#.*|\s*)$/ # filter comment lines and blank lines
  end.join
end

task :default => :spec

desc 'Run specs'
task :spec do
  system 'bin/rspec spec'
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
    system 'make clean'
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
    system 'make clean && make'
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
    sh 'aws put ' +
      "s3.wincent.com/command-t/releases/command-t-#{version}.vba " +
      "command-t-#{version}.vba"
    sh 'aws put ' +
      "s3.wincent.com/command-t/releases/command-t-#{version}.vba?acl " +
      '--public'
  end

  desc 'Upload current vimball to www.vim.org'
  task :vim => :vimball do
    prepare_release_notes
    conf = {
      :file     => "command-t-#{version}.vba",
      :id       => 3025,
      :message  => read_release_notes.chomp,
      :version  => version
    }
    File.open('.vim_org.yml', 'w') { |f| f.print conf.to_yaml }
    sh "vendor/vimscriptuploader/vimscriptuploader.rb --config ~/.vim_org.yml .vim_org.yml"
  end

  desc 'Upload current vimball everywhere'
  task :all => [ :s3, :vim ]
end

desc 'Add current vimball to releases branch'
task :archive => :vimball do
  v = version # store version before switching branches
  sh 'git stash && ' +
     'git checkout releases && ' +
     "git add command-t-#{v}.vba && " +
     "git commit -s -m 'Add #{v} release vimball' && " +
     'git checkout @{-1} && ' +
     'git stash pop'
end
