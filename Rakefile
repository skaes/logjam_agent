require 'bundler/setup'
require 'rake'
require 'rake/testtask'
require 'bundler/gem_tasks'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
  t.ruby_opts = %w(-W1)
end

task :default do
  Rake::Task[:test].invoke
end

task :integration do
  sh "cd railsapp && rake"
end
