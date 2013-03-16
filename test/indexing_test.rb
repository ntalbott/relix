require 'test_helper'
require 'support/redis_wrapper'

class IndexingTest < RelixTest
  def test_multi_value_index
    klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :name, on: %w(first last)
      end
      attr_accessor :key, :first, :last
    end
    object = klass.new
    object.key = 1
    object.first = "bob"
    object.last = "smith"
    object.index!
    assert_equal ["1"], klass.lookup{|q| q[:name].eq(first: "bob", last: "smith")}
    assert_equal [], klass.lookup{|q| q[:name].eq(first: "fred", last: "smith")}
    assert_raise Relix::MissingIndexValueError do
      klass.lookup{|q| q[:name].eq(first: "bob")}
    end
  end

  def test_index_inheritance
    parent = Class.new do
      def self.name; "parent"; end
      include Relix
      relix do
        primary_key :key
        unique :email
      end
      attr_accessor :key, :email
    end
    child = Class.new(parent) do
      def self.name; "child"; end
      relix do
        unique :login
      end
      attr_accessor :login
    end
    object = child.new
    object.key = "1"
    object.email = "bob@example.com"
    object.login = 'bob'
    object.index!
    assert_equal ["1"], child.lookup{|q| q[:email].eq("bob@example.com")}
  end

  def test_missing_primary_key
    klass = Class.new do
      include Relix
    end
    assert_raise Relix::MissingPrimaryKeyError do
      klass.new.index!
    end
  end

  def test_error_indexing
    bogus_index = Class.new(Relix::Index) do
      def index(r, pk, object, value, old_value)
        r.set('a', 'a')
        r.hget('a', 'a')
      end
      def self.name
        "BogusIndex"
      end
    end
    Relix.register_index(bogus_index)
    klass = Class.new do
      include Relix
      relix do
        primary_key :key
        bogus :stuff
      end
      attr_accessor :key, :stuff
    end
    object = klass.new
    object.key = 'a'
    object.stuff = 'a'
    assert_raise Relix::RedisIndexingError do
      object.index!
    end
  end

  def test_out_of_memory_while_indexing
    klass = Class.new do
      include Relix
      relix.primary_key :key
      attr_accessor :key
    end

    klass.relix.redis = Relix.new_redis_client
    def (klass.relix.redis).multi
      yield
      RuntimeError.new("ERR command not allowed when used memory > 'maxmemory'")
    end

    object = klass.new
    object.key = "a"
    assert_raise Relix::RedisIndexingError do
      object.index!
    end
  end

  def test_immutable_attribute_indexing
    klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :other, immutable_attribute: true
      end

      attr_accessor :key, :other
      def self.name; "MyKlass"; end
    end

    object = klass.new
    object.key = 1
    object.other = "foo"
    object.index!
    assert !Relix.redis.keys.include?(klass.relix.current_values_name("1")), 'expected redis to not have a current_values keys for MyKlass'

    # ensure we can deindex it...
    assert_equal %w(1), klass.lookup { |q| q[:other].eq("foo") }
    object.deindex!
    assert_equal %w(), klass.lookup { |q| q[:other].eq("foo") }
  end

  def test_indexing_interrogative_method
    klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :other, on: :other?
      end

      attr_accessor :key
      attr_writer :other

      def other?
        @other
      end
    end

    object = klass.new
    object.key = 1
    object.other = true
    object.index!

    object = klass.new
    object.key = 2
    object.other = nil
    object.index!

    object = klass.new
    object.key = 3
    object.other = false
    object.index!

    object = klass.new
    object.key = 4
    object.other = "bob"
    object.index!

    assert_equal %w(1 4), klass.lookup { |q| q[:other].eq(true) }
    assert_equal %w(2 3), klass.lookup { |q| q[:other].eq(false) }
  end
end
