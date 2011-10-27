require 'redix'

require 'fixtures/family_fixture'

if `redis-cli -p 10000 PING 2>&1` =~ /PONG/
  raise "Redis is already running!"
else
  pid = Process.spawn("redis-server #{File.expand_path('..', __FILE__)}/redis.conf", [:out, :err] => "/dev/null")
  at_exit{Process.kill("TERM", pid)}
end
Redix.port = 10000

require 'test/unit'

class RedixTest < Test::Unit::TestCase
  def run(*args)
    shared_setup
    super
  end

  def shared_setup
    Redix.redis.flushdb
  end
end