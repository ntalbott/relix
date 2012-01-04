require 'test_helper'

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
      fork do
        model.relix.redis = Relix.new_redis_client
        model.thing = "value two"
        model.index!
        assert_equal %w(1), @m.lookup{|q| q[:thing].eq("value two")}
        assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}
        assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("value one")}
      end
      Process.wait
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
      fork do
        model.relix.redis = Relix.new_redis_client
        model.thing = "value two"
        model.index!
      end
      Process.wait
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

  class RedisWrapper
    def initialize(wrapped)
      @wrapped = wrapped
      @befores = {}
      @afters = {}
    end

    def before(method, &before)
      @befores[method.to_sym] = before
    end

    def after(method, &after)
      @afters[method.to_sym] = after
    end

    def method_missing(m, *args, &block)
      if @befores[m]
        @befores.delete(m).call
      end
      r = @wrapped.send(m, *args, &block)
      if @afters[m]
        @afters.delete(m).call
      end
      r
    end
  end
end