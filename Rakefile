begin
  require 'spec/rake/spectask'
rescue LoadError
end

SPEC_FILES = FileList['spec/**/*_spec.rb']

desc "Run specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files  = SPEC_FILES
  t.spec_opts   = ['--options', 'spec/spec.opts']
end
