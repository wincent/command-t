begin
  require 'spec/rake/spectask'
rescue LoadError
end

task :default => :spec

desc "Run specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files  = FileList['spec/**/*_spec.rb']
  t.spec_opts   = ['--options', 'spec/spec.opts']
end
