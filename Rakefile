begin
  require 'spec/rake/spectask'
rescue LoadError
end

task :default => :spec

desc 'Run specs'
Spec::Rake::SpecTask.new do |t|
  t.spec_files  = FileList['spec/**/*_spec.rb']
  t.spec_opts   = ['--options', 'spec/spec.opts']
end

desc 'Create vimball archive'
task :make do
  system 'make'
end

desc 'Compile under all multiruby versions'
task :compile do
  system './compile-test.sh'
end

desc 'Run specs under all multiruby versions'
task :multispec do
  system './multi-spec.sh'
end

desc 'Check that the current HEAD is tagged'
task :check_tag do
  system 'git describe --exact-match HEAD 2> /dev/null'
  if $?.exitstatus != 0
    puts 'warning: current HEAD is not tagged'
  end
end

desc 'Run checks prior to release'
task :prerelease => [:compile, :multispec, :make]
