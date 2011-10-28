require 'test_helper'

class IndexingTest < RedixTest
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
end