require 'test_helper'

class IndexingTest < RedixTest
  def test_multi_value_index
    klass = Class.new do
      include Redix
      redix do
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
    assert_raise Redix::MissingIndexValue do
      klass.lookup{|q| q[:name].eq(first: "bob")}
    end
  end

  def test_index_inheritance
    parent = Class.new do
      def self.name; "parent"; end
      include Redix
      redix do
        primary_key :key
        unique :email
      end
      attr_accessor :key, :email
    end
    child = Class.new(parent) do
      def self.name; "child"; end
      redix do
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
      include Redix
    end
    assert_raise Redix::MissingPrimaryKeyError do
      klass.new.index!
    end
  end

  def test_error_indexing
    bogus_index = Class.new(Redix::Index) do
      def index(r, pk, object, value, old_value)
        r.set('a', 'a')
        r.hget('a', 'a')
      end
    end
    Redix.register_index(:bogus, bogus_index)
    klass = Class.new do
      include Redix
      redix do
        primary_key :key
        bogus :stuff
      end
      attr_accessor :key, :stuff
    end
    object = klass.new
    object.key = 'a'
    object.stuff = 'a'
    assert_raise Redix::RedisIndexingError do
      object.index!
    end
  end
end