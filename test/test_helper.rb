require 'test/unit'

require 'redix'

require 'fixtures/family_fixture'

class RedixTest < Test::Unit::TestCase
  def run(*args)
    shared_setup
    super
  end

  def shared_setup
    Redix.redis.flushdb
  end
end