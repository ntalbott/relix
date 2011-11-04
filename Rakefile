require "bundler"
Bundler.setup

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task default: :test

gemspec = eval(File.read("relix.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["relix.gemspec"] do
  system "gem build relix.gemspec"
  system "gem install relix-#{Relix::VERSION}.gem"
end