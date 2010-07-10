require 'rubygems'
require 'bundler'
Bundler.setup
require 'rspec/core/rake_task'

def bail_on_failure
  exitstatus = $?.exitstatus
  if exitstatus != 0
    raise "last command failed with exit status #{exitstatus}"
  end
end

task :default => :spec

desc 'Run specs'
RSpec::Core::RakeTask.new do |t|
  t.pattern = './spec/**/*_spec.rb'
end

desc 'Create vimball archive'
task :make do
  system 'make'
  bail_on_failure
end

desc 'Compile under all multiruby versions'
task :compile do
  system './compile-test.sh'
  bail_on_failure
end

desc 'Run specs under all multiruby versions'
task :multispec do
  system './multi-spec.sh'
  bail_on_failure
end

desc 'Check that the current HEAD is tagged'
task :check_tag do
  system 'git describe --exact-match HEAD 2> /dev/null'
  if $?.exitstatus != 0
    puts 'warning: current HEAD is not tagged'
  end
end

desc 'Run checks prior to release'
task :prerelease => [:compile, :multispec, :make, :check_tag]
