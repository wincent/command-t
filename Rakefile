def bail_on_failure
  exitstatus = $?.exitstatus
  if exitstatus != 0
    raise "last command failed with exit status #{exitstatus}"
  end
end

def version
  `git describe`.chomp
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
  system 'git describe --exact-match HEAD 2> /dev/null'
  if $?.exitstatus != 0
    puts 'warning: current HEAD is not tagged'
  end
end

desc 'Run checks prior to release'
task :prerelease => ['make:all', 'spec:all', :vimball, :check_tag]

desc 'Upload current vimball to Amazon S3'
task :upload => :vimball do
  sh 'aws put ' +
     "s3.wincent.com/command-t/releases/command-t-#{version}.vba " +
     "command-t-#{version}.vba"
  sh 'aws put ' +
     "s3.wincent.com/command-t/releases/command-t-#{version}.vba?acl " +
     '--public'
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
