require 'test_helper'
require 'support/redis_wrapper'

class ConditionalIndexingTest < RelixTest
  def setup
    @klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :name, on: %w(first last), if: :full_name?
      end
      attr_accessor :key, :first, :last
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

  def test_deindex_if_condition_changes
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
    assert !Relix.redis.hgetall(@klass.relix.current_values_name("1")).has_key?("name")
  end
end
