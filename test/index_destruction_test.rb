require 'test_helper'
require 'support/redis_wrapper'

class IndexDestructionTest < RelixTest
  def setup
    original_klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :other
        multi :keep
        multi :immutable, immutable_attribute: true
      end
      attr_accessor :key, :other, :keep

      def self.name; "MyKlass"; end

      def immutable
        "does not change"
      end
    end

    object1 = original_klass.new
    object1.key = 1
    object1.other = "foo"
    object1.index!

    object2 = original_klass.new
    object2.key = 2
    object2.other = "bar"
    object2.index!

    @klass = Class.new do
      include Relix
      relix do
        primary_key :key
        obsolete{multi :other}
        multi :keep
        obsolete{multi :immutable, immutable_attribute: true}
      end
      attr_accessor :key, :other, :keep

      def self.name; "MyKlass"; end

      def immutable
        "does not change"
      end
    end
  end

  def test_obsolete_index_is_not_usable
    assert_raise Relix::MissingIndexError do
      @klass.lookup{|q| q[:other].eq("foo")}
    end
  end

  def test_obsolete_index_is_not_indexed
    object = @klass.new
    object.key = 3
    object.other = "baz"
    object.index!

    assert_equal 3, @klass.lookup.count
    assert_equal 0, Relix.redis.keys("*baz*").size
    assert_equal 1, Relix.redis.keys("*foo*").size
  end

  def test_obsolete_index_can_be_destroyed
    @klass.relix.destroy_index(:other)

    assert_equal 2, @klass.lookup.count
    assert_equal ["keep"], Relix.redis.hgetall(@klass.relix.current_values_name("1")).keys
    assert_equal ["keep"], Relix.redis.hgetall(@klass.relix.current_values_name("2")).keys

    assert_equal 0, Relix.redis.keys("*other*").size, Relix.redis.keys("*other*")
  end

  def test_destroying_non_obsolete_index
    assert_raise Relix::MissingIndexError do
      @klass.relix.destroy_index(:keep)
    end
  end

  def test_destroying_primary_key_index
    assert_raise Relix::InvalidIndexError do
      Class.new do
        include Relix
        relix do
          obsolete{primary_key :key}
        end
        attr_accessor :key
      end
    end
  end

  def test_destroying_an_immutable_index
    assert_raise Relix::InvalidIndexError do
      @klass.relix.destroy_index(:immutable)
    end
  end

  def test_obsolete_shadowing_standard_index
    assert_raise Relix::InvalidIndexError do
      Class.new do
        include Relix
        relix do
          primary_key :key
          multi :other
          obsolete{multi :other}
        end
        attr_accessor :key, :other
      end
    end

    assert_raise Relix::InvalidIndexError do
      Class.new do
        include Relix
        relix do
          primary_key :key
          obsolete{multi :other}
          multi :other
        end
        attr_accessor :key, :other
      end
    end
  end

  def test_deindexing_deindexes_obsolete_indexes
    object = @klass.new
    object.key = 1
    object.other = "foo"
    object.deindex!

    assert_equal 1, @klass.lookup.count
    assert_equal [], Relix.redis.hgetall(@klass.relix.current_values_name("1")).keys
    assert_equal ["other", "keep"], Relix.redis.hgetall(@klass.relix.current_values_name("2")).keys

    assert_equal 0, Relix.redis.keys("*foo*").size, Relix.redis.keys("*foo*")
  end
end
