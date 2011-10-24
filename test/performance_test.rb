require 'test_helper'

class PerformanceTest < RedixTest
  def test_double_index
    m = Class.new do
      include Redix
      redix do
        primary_key :key
        multi :one
        multi :two
      end
      attr_reader :key, :one, :two
      def initialize(key, one, two); @key, @one, @two = key, one, two; index!; end
    end

    10.times do |i|
      0.step(10).each do |one|
        0.step(10).each do |two|
          assert_time 700, profiling: "indexing #{i}, #{one}, #{two}", delta: -1 do
            m.new(rand(1000000000), one, two)
          end
        end
      end
    end

    assert_time 50, profiling: 'lookup', delta: 20 do
      m.lookup do |q|
        q[:one].eq(50)
        q[:two].eq(500)
      end
    end
  end

  def test_sorting
    m = Class.new do
      include Redix
      redix do
        primary_key :key
        ordered :sortme
      end
      attr_reader :key, :sortme
      def initialize(key, sortme); @key, @sortme = key, sortme; index!; end
    end

    100.times do |i|
      assert_time 1000, profiling: "indexing #{i}", delta: -1 do
        m.new(rand(1_000_000_000), rand(1_000_000_000))
      end
    end

    assert_time 500, profiling: 'lookup', delta: 350 do
      m.lookup{|q| q.sort(:sortme)}
    end
  end

  def assert_time(expected_ticks, options={})
    delta = options[:delta] || 50
    profiling = options[:profiling]
    tick = (time{Redix.redis.echo("Tick")}/10)
    actual_time = time{yield}
    actual_ticks = (actual_time / tick)
    difference = (expected_ticks - actual_ticks)
    assert (actual_ticks < expected_ticks), "Expected #{expected_ticks} ticks (or less)#{" for #{profiling}" if profiling} but was #{actual_ticks.to_i} ticks (+#{difference.to_i.abs}). Time on this machine was #{(actual_time * 1000).round(2)} milliseconds."
    if delta >= 0
      assert difference < delta, "#{actual_ticks} is TOO FAST#{" for #{profiling}" if profiling}; expected max delta #{delta} from #{expected_ticks} but was #{difference}"
    end
  end

  def time
    start = Time.now
    yield
    (Time.now - start)
  end
end