def bail_on_failure
  exitstatus = $?.exitstatus
  if exitstatus != 0
    raise "last command failed with exit status #{exitstatus}"
  end
end

task :default => :spec

desc 'Run specs'
task :spec do
  system 'bin/rspec spec'
  bail_on_failure
end

desc 'Create vimball archive'
task :vimball do
  system 'make'
  bail_on_failure
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
