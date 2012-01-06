require 'test_helper'
require 'support/redis_wrapper'

class ConcurrencyTest < RelixTest
  def setup
    @m = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :thing
      end
      attr_accessor :key, :thing
      def initialize(key, thing); @key, @thing = key, thing; index!; end
    end
    @m.relix.redis = RedisWrapper.new(@m.relix.redis)
  end

  def test_value_changes_mid_indexing
    model = @m.new(1, "original")
    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}

    model.thing = "value one"

    model.relix.redis.before(:multi) do
      concurrently do
        model.relix.redis = Relix.new_redis_client
        model.thing = "value two"
        model.index!
        assert_equal %w(1), @m.lookup{|q| q[:thing].eq("value two")}
        assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}
        assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("value one")}
      end
    end

    model.index!
    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("value one")}
    assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}
    assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("value two")}
  end

  def test_value_changes_mid_indexing_unrecoverably
    model = @m.new(1, "original")
    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}

    model.thing = "value one"

    create_conflict = proc do
      concurrently do
        model.relix.redis = Relix.new_redis_client
        model.thing = "value two"
        model.index!
      end
      model.relix.redis.after(:multi) do
        model.relix.redis.before(:multi, &create_conflict)
      end
    end
    model.relix.redis.before(:multi, &create_conflict)

    assert_raise(Relix::ExceededRetriesForConcurrentWritesError) do
      model.index!
    end

    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("value two")}
    assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}
    assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("value one")}
  end

  def test_value_changes_mid_deindexing
    model = @m.new(1, "original")
    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}

    model.relix.redis.before(:multi) do
      concurrently do
        model.relix.redis = Relix.new_redis_client
        model.thing = "other"
        model.index!
        assert_equal %w(1), @m.lookup{|q| q[:thing].eq("other")}
      end
    end

    model.deindex!

    assert_equal [], @m.lookup
  end

  def test_value_changes_mid_deindexing_unrecoverably
    model = @m.new(1, "original")
    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}

    create_conflict = proc do
      concurrently do
        model.relix.redis = Relix.new_redis_client
        model.thing = "other"
        model.index!
      end

      model.relix.redis.after(:multi) do
        model.relix.redis.before(:multi, &create_conflict)
      end
    end

    model.relix.redis.before(:multi, &create_conflict)

    assert_raise(Relix::ExceededRetriesForConcurrentWritesError) do
      model.deindex!
    end

    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("other") }
  end

  def concurrently(&block)
    fork(&block)
    Process.wait
  end
end
