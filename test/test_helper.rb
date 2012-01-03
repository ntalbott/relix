require 'relix'

if `redis-cli -p 10000 PING 2>&1` =~ /PONG/
  raise "Redis is already running!"
else
  pid = Process.spawn("redis-server #{File.expand_path('..', __FILE__)}/redis.conf", [:out, :err] => "/dev/null")
  at_exit{Process.kill("TERM", pid)}
end
Relix.port = 10000

require 'test/unit'

require 'fixtures/family_fixture'

class RelixTest < Test::Unit::TestCase
  def run(*args)
    shared_setup
    super
  end

  def shared_setup
    Relix.redis.flushdb
  end
end