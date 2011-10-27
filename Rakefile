require "bundler"
Bundler.setup

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task default: :test

gemspec = eval(File.read("redix.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["redix.gemspec"] do
  system "gem build redix.gemspec"
  system "gem install redix-#{Redix::VERSION}.gem"
end