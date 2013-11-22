require 'test_helper'
require 'support/redis_wrapper'

class ConditionalIndexingTest < RelixTest
  def setup
    @klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :name, on: %w(first last), if: :full_name?
        multi :email
        multi :alive, if: :alive
      end
      attr_accessor :key, :first, :last, :email, :alive
      def full_name?; (first && last); end
    end
  end

  def test_indexes_if_condition_met
    object = @klass.new
    object.key = 1
    object.first = "bob"
    object.last = "smith"
    object.index!
    assert_equal ["1"], @klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}
  end

  def test_does_not_index_if_condition_not_met
    object = @klass.new
    object.key = 1
    object.first = "bob"
    object.last = nil
    object.index!
    assert_equal [], @klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}
    assert_equal [], @klass.lookup{|q| q[:name].eq(first: "bob", last: nil)}
  end

  def test_condition_changes
    object = @klass.new
    object.key = 1
    object.first = "bob"
    object.last = "smith"
    object.index!
    assert_equal ["1"], @klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}

    object.last = nil
    object.index!
    assert_equal [], @klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}
    assert_equal [], @klass.lookup{|q| q[:name].eq(first: "bob", last: nil)}
    assert_equal %w(email), Relix.redis.hgetall(@klass.relix.current_values_name("1")).keys

    object.last = "smith"
    object.index!
    assert_equal ["1"], @klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}
    assert_equal [], @klass.lookup{|q| q[:name].eq(first: "bob", last: nil)}
    assert_equal %w(email name).sort, Relix.redis.hgetall(@klass.relix.current_values_name("1")).keys.sort
  end

  def test_multiple_conditions_changing
    object = @klass.new
    object.key = 1
    object.first = "bob"
    object.last = "smith"
    object.alive = true
    object.index!
    assert_equal ["1"], @klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}
    assert_equal ["1"], @klass.lookup{|q| q[:alive].eq(alive: true)}
    assert_equal [], @klass.lookup{|q| q[:alive].eq(alive: false)}

    object.first = nil
    object.alive = false
    object.index!
    assert_equal [], @klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}
    assert_equal [], @klass.lookup{|q| q[:name].eq(first: "bob", last: nil)}
    assert_equal [], @klass.lookup{|q| q[:alive].eq(alive: true)}
    assert_equal [], @klass.lookup{|q| q[:alive].eq(alive: false)}

    assert_equal %w(email), Relix.redis.hgetall(@klass.relix.current_values_name("1")).keys

    object.first = "bob"
    object.alive = true
    object.index!
    assert_equal ["1"], @klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}
    assert_equal [], @klass.lookup{|q| q[:name].eq(first: "bob", last: nil)}
    assert_equal ["1"], @klass.lookup{|q| q[:alive].eq(alive: true)}

    assert_equal %w(email name alive).sort, Relix.redis.hgetall(@klass.relix.current_values_name("1")).keys.sort
  end

end
