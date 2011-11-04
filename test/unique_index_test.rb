require 'test_helper'

class UniqueIndexTest < RedixTest
  def test_enforcement
    m = Class.new do
      include Redix
      redix do
        primary_key :key
        unique :email
      end
      attr_accessor :key, :email
      def initialize(k,e); @key,@email = k,e; index! end
    end

    assert_nothing_raised do
      m.new("1", "bob@example.com")
    end
    assert_equal ["1"], m.lookup{|q| q[:email].eq("bob@example.com")}

    assert_raise(Redix::NotUniqueError) do
      m.new("2", "bob@example.com")
    end
    assert_equal ["1"], m.lookup{|q| q[:email].eq("bob@example.com")}
    assert_equal ["1"], m.lookup

    assert_nothing_raised do
      m.new("2", "jane@example.com")
    end
    assert_equal ["1"], m.lookup{|q| q[:email].eq("bob@example.com")}
    assert_equal ["2"], m.lookup{|q| q[:email].eq("jane@example.com")}

    assert_nothing_raised do
      m.new("1", "fred@example.com")
    end
    assert_equal ["1"], m.lookup{|q| q[:email].eq("fred@example.com")}
    assert_equal ["2"], m.lookup{|q| q[:email].eq("jane@example.com")}

    assert_nothing_raised do
      m.new("3", "")
      m.new("1", nil)
      m.new("2", nil)
    end
    assert_equal [], m.lookup{|q| q[:email].eq(nil)}
    assert_equal [], m.lookup{|q| q[:email].eq("fred@example.com")}
  end

  def test_deindexing_old_values
    m = Class.new do
      include Redix
      redix do
        primary_key :key
        unique :email
      end
      attr_accessor :key, :email
    end
    o = m.new
    o.key = 'a'
    o.email = 'bob@example.com'
    o.index!
    assert_equal ['a'], m.lookup{|q| q[:email].eq('bob@example.com')}

    o.email = 'fred@example.com'
    o.index!
    assert_equal [], m.lookup{|q| q[:email].eq('bob@example.com')}
    assert_equal ['a'], m.lookup{|q| q[:email].eq('fred@example.com')}
  end
end