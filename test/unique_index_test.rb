require 'test_helper'

class UniqueIndexTest < RelixTest
  def setup
    @m = Class.new do
      include Relix
      relix do
        primary_key :key
        unique :email
      end
      attr_accessor :key, :email
      def initialize(k,e); @key,@email = k,e; index! end
    end
  end

  def test_enforcement
    assert_nothing_raised do
      @m.new("1", "bob@example.com")
    end
    assert_equal ["1"], @m.lookup{|q| q[:email].eq("bob@example.com")}

    assert_raise(Relix::NotUniqueError) do
      @m.new("2", "bob@example.com")
    end
    assert_equal ["1"], @m.lookup{|q| q[:email].eq("bob@example.com")}
    assert_equal ["1"], @m.lookup

    assert_nothing_raised do
      @m.new("2", "jane@example.com")
    end
    assert_equal ["1"], @m.lookup{|q| q[:email].eq("bob@example.com")}
    assert_equal ["2"], @m.lookup{|q| q[:email].eq("jane@example.com")}

    assert_nothing_raised do
      @m.new("1", "fred@example.com")
    end
    assert_equal ["1"], @m.lookup{|q| q[:email].eq("fred@example.com")}
    assert_equal ["2"], @m.lookup{|q| q[:email].eq("jane@example.com")}

    assert_nothing_raised do
      @m.new("3", "")
      @m.new("1", nil)
      @m.new("2", nil)
    end
    assert_equal [], @m.lookup{|q| q[:email].eq(nil)}
    assert_equal [], @m.lookup{|q| q[:email].eq("fred@example.com")}
  end

  def test_deindexing_old_values
    o = @m.new('a', 'bob@example.com')
    assert_equal ['a'], @m.lookup{|q| q[:email].eq('bob@example.com')}

    o.email = 'fred@example.com'
    o.index!
    assert_equal [], @m.lookup{|q| q[:email].eq('bob@example.com')}
    assert_equal ['a'], @m.lookup{|q| q[:email].eq('fred@example.com')}
  end

  def test_forced_deindex
    o = @m.new('a', 'bob@example.com')
    assert_equal ['a'], @m.lookup{|q| q[:email].eq('bob@example.com')}
    o.deindex!
    assert_equal [], @m.lookup{|q| q[:email].eq('bob@example.com')}
  end

  def test_searching_for_nil
    o = @m.new('a', nil)
    assert_equal [], @m.lookup{|q| q[:email].eq(nil)}

    assert_equal [], @m.lookup{|q| q[:email].eq(nil, limit: 1)}
  end

  def test_index_destruction
    original_klass = Class.new do
      include Relix
      relix do
        primary_key :key
        unique :other
      end
      attr_accessor :key, :other

      def self.name; "MyKlass"; end
    end

    object1 = original_klass.new
    object1.key = 1
    object1.other = "foo"
    object1.index!

    object2 = original_klass.new
    object2.key = 2
    object2.other = "bar"
    object2.index!

    klass = Class.new do
      include Relix
      relix do
        primary_key :key
        obsolete{unique :other}
      end
      attr_accessor :key, :other

      def self.name; "MyKlass"; end
    end

    klass.relix.destroy_index(:other)

    assert_equal 2, klass.lookup.count
    assert_equal [], Relix.redis.hgetall(klass.relix.current_values_name("1")).keys
    assert_equal [], Relix.redis.hgetall(klass.relix.current_values_name("2")).keys

    assert_equal 0, Relix.redis.keys("*other*").size, Relix.redis.keys("*other*")
  end
end
