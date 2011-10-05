require 'test_helper'

class PerformanceTest < RedixTest
  def setup
    @m = Class.new do
      include Redix
      primary_key :key
      index :one
      index :two
      attr_reader :key, :one, :two
      def initialize(key, one,two); @key, @one, @two = key, one, two; index!; end
    end
  end

  def test_double_index
    10.times do
      0.step(10).each do |one|
        0.step(10).each do |two|
          @m.new(rand(1000000000), one, two)
        end
      end
    end

    assert_time 40 do
      @m.lookup do |q|
        q[:one].eq(50)
        q[:two].eq(500)
      end
    end
  end

  def test_indexing
    assert_time 60 do
      @m.new(rand(1000000000), 1, 2)
    end
  end

  def assert_time(expected_ticks)
    tick = (time{Redix.redis.echo("Tick")}/10)
    actual_ticks = (time{yield} / tick)
    difference = (expected_ticks - actual_ticks)
    assert (actual_ticks < expected_ticks), "Expected #{expected_ticks} ticks (or less) but was #{actual_ticks.to_i} ticks (+#{difference.to_i.abs})"
    delta = 50
    assert difference < delta, "#{actual_ticks} is TOO FAST; expected max delta #{delta} but was #{difference}"
  end

  def time
    start = Time.now
    yield
    (Time.now - start)
  end
end