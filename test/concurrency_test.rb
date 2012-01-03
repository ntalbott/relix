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
    @m.relix.instance_eval{@redis = PausableRedis.new(@redis)}
  end

  def test_value_changes_mid_indexing
    model = @m.new(1, "original")
    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}

    model.thing = "value one"

    pause_indexing(model) do
      fork do
        model.relix.instance_eval{@redis = Relix.new_redis_client}
        model.thing = "value two"
        model.index!
        assert_equal %w(1), @m.lookup{|q| q[:thing].eq("value two")}
        assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}
        assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("value one")}
      end
      Process.wait
    end
    assert_equal %w(1), @m.lookup{|q| q[:thing].eq("value one")}
    assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("original")}
    assert_not_equal %w(1), @m.lookup{|q| q[:thing].eq("value two")}
  end

  class PausableRedis
    def initialize(wrapped)
      @wrapped = wrapped
      @pauses = {}
    end

    def pause(method, while_paused)
      @pauses[method.to_sym] = while_paused
    end

    def method_missing(m, *args, &block)
      if @pauses[m]
        while_paused, @pauses[m] = @pauses[m], nil
        while_paused.call
      end
      @wrapped.send(m, *args, &block)
    end
  end

  def pause_indexing(model, &block)
    model.relix.redis.pause(:multi, block)
    model.index!
  end
end