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
          assert_time 600, profiling: "indexing #{i}, #{one}, #{two}", delta: -1 do
            m.new(rand(1000000000), one, two)
          end
        end
      end
    end

    assert_time 35, profiling: 'lookup', delta: 10 do
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
      assert_time 600, profiling: "indexing #{i}", delta: -1 do
        m.new(rand(1_000_000_000), rand(1_000_000_000))
      end
    end

    assert_time 390, profiling: 'lookup' do
      m.lookup{|q| q.sort(:sortme)}
    end
  end

  def assert_time(expected_ticks, options={}, &block)
    delta = options[:delta] || 50
    profiling = options[:profiling]
    result = check_time(expected_ticks, &block)
    unless result[0]
      print "R#{profiling[0...1] if profiling} " if ENV["PERFTWEAK"]
      result = ([result] + (1..8).collect{
        check_time(expected_ticks, &block)
      }).sort_by{|_, ticks, _| ticks}[4]
    end
    difference = (expected_ticks - result[1])
    assert result[0], "Expected #{expected_ticks} ticks (or less)#{" for #{profiling}" if profiling} but was #{result[1]} ticks (+#{difference.to_i.abs}). Time on this machine was #{(result[2] * 1000).round(2)} milliseconds."

    if delta >= 0
      assert difference < delta, "#{result[1]} is TOO FAST#{" for #{profiling}" if profiling}; expected max delta #{delta} from #{expected_ticks} but was #{difference}"
    end
  end

  def check_time(expected_ticks)
    tick = (time{Redix.redis.echo("Tick")}/10)
    actual_time = time{yield}
    actual_ticks = (actual_time / tick)
    [(actual_ticks < expected_ticks), actual_ticks, actual_time]
  end

  def time
    start = Time.now
    yield
    (Time.now - start)
  end
end