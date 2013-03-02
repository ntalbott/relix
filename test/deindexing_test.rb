require 'test_helper'
require 'support/redis_wrapper'

class DeindexingTest < RelixTest
  def test_deindexing_removes_current_value_key
    klass = Class.new do
      include Relix
      relix { primary_key :key; multi :other }
      attr_accessor :key

      def other; "bar"; end
      def self.name; "MyKlass"; end
    end
    object = klass.new
    object.key = 1
    object.index!
    assert Relix.redis.keys.include?(klass.relix.current_values_name("1")), 'expected redis to have a current_values keys for MyKlass'
    assert_equal 1, klass.lookup.count

    object.deindex!
    assert !Relix.redis.keys.include?(klass.relix.current_values_name("1")), 'expected redis not to have a current_values keys for MyKlass'
    assert_equal 0, klass.lookup.count
  end

  def test_deindexing_by_key_removes_keys
    klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :other
        unique :email
        ordered :sort
      end
      attr_accessor :key

      def other; "bar"; end
      def email; "bob@example.com"; end
      def sort; 1; end
      def self.name; "MyKlass"; end
    end
    object = klass.new
    object.key = 1
    object.index!
    assert Relix.redis.keys.include?(klass.relix.current_values_name("1")), 'expected redis to have a current_values keys for MyKlass'
    assert_equal 1, klass.lookup.count
    assert_equal 1, klass.lookup{|q| q[:other].eq("bar")}.size
    assert_equal 1, klass.lookup{|q| q[:email].eq("bob@example.com")}.size
    assert_equal 1, klass.lookup{|q| q[:sort].gt(0)}.size

    klass.deindex_by_primary_key!(object.key)
    assert !Relix.redis.keys.include?(klass.relix.current_values_name("1")), 'expected redis not to have a current_values keys for MyKlass'
    assert_equal 0, klass.lookup.count
    assert_equal 0, klass.lookup{|q| q[:other].eq("bar")}.size
    assert_equal 0, klass.lookup{|q| q[:email].eq("bob@example.com")}.size
    assert_equal 0, klass.lookup{|q| q[:sort].gt(0)}.size
  end

  def test_deindexing_by_key_twice
    klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :other
        unique :email
        ordered :sort
      end
      attr_accessor :key

      def other; "bar"; end
      def email; "bob@example.com"; end
      def sort; 1; end
      def self.name; "MyKlass"; end
    end

    object = klass.new
    object.key = 1
    object.index!
    assert_equal 1, klass.lookup.count

    klass.deindex_by_primary_key!(object.key)
    klass.deindex_by_primary_key!(object.key)
    assert_equal 0, klass.lookup.count
  end
end
