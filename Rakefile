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

multiruby = `which multiruby`.chomp
if multiruby.length > 0
  namespace :multi do
    desc "Run specs under multiruby"
    Spec::Rake::SpecTask.new do |t|
      t.spec_files  = SPEC_FILES
      t.spec_opts   = ['--options', 'spec/spec.opts']
      t.ruby_cmd    = multiruby
    end
  end
end

