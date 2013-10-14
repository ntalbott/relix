require "bundler"
Bundler.setup

task :test
  abort("Use script/test")
end
task default: :test

gemspec = eval(File.read("relix.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["relix.gemspec"] do
  system "gem build relix.gemspec"
  system "gem install relix-#{Relix::VERSION}.gem"
end
