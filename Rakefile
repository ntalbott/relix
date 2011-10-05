require "bundler"
Bundler.setup

ROOT = File.expand_path('..', __FILE__)

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList['test/*_test.rb']
  t.verbose = true
end

task :redis do
  if `redis-cli -p 10000 PING` =~ /PONG/
    raise "Redis is already running!"
  else
    pid = Process.spawn("redis-server #{ROOT}/test/redis.conf", [:out, :err] => "/dev/null")
    at_exit{Process.kill("TERM", pid)}
  end
end

task test: :redis

task default: :test

gemspec = eval(File.read("redix.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["redix.gemspec"] do
  system "gem build redix.gemspec"
  system "gem install redix-#{Redix::VERSION}.gem"
end