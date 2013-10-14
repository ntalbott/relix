system("redis-cli -p 20000 SHUTDOWN 2>&1") if(`redis-cli -p 20000 PING 2>&1` =~ /PONG/)
system("redis-server #{File.expand_path('..', __FILE__)}/redis.conf")

require 'test/unit'

require 'relix'
Relix.port = 20000

require 'fixtures/family_fixture'

class RelixTest < Test::Unit::TestCase
  def run(*args)
    shared_setup
    super
  end

  def shared_setup
    Relix.redis.flushdb
  rescue Errno::ECONNREFUSED
    warn "Unable to connect to redis so db was not flushed."
  end
end
