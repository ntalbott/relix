require 'test_helper'

class MultiIndexTest < RelixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_lookup
    assert_equal @talbotts.collect{|e| e.key}.sort, Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}.sort
    assert_equal [], Person.lookup{|q| q[:family_key].eq("bogus")}
  end

  def test_count
    assert_equal @talbotts.size, Person.lookup_count(:family_key, @talbott_family.key)
  end

  def test_deindex
    assert Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}.include?(@nathaniel.key), "expected Talbott family to include Nathaniel's key"
    @nathaniel.delete
    assert !Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}.include?(@nathaniel.key), "expected Talbott family not to include Nathaniel's key"
  end

  def test_offset_by_key
    assert_equal %w(reuben annemarie), Person.lookup{|q| q[:family_key].eq(@talbott_family.key, from: "nathaniel", limit: 2)}
  end

  def test_offset_by_missing_key
    assert_raise Relix::MissingIndexValueError do
      Person.lookup{|q| q[:family_key].eq(@talbott_family.key, from: "bogus", limit: 2)}
    end
  end

  def test_limit_of_zero
    assert_equal [], Person.lookup{|q| q[:family_key].eq(@talbott_family.key, limit: 0)}
  end

  def test_index_values
    assert_equal %w(talbott omelia).sort, Person.lookup_values(:family_key).sort
  end

  def test_values_not_indexed
    model = Class.new do
      include Relix
      relix.multi :to_s
    end

    assert_raise Relix::ValuesNotIndexedError do
      model.lookup_values(:to_s)
    end
  end

  def test_values_deindexed
    @talbotts[0..-2].each{|t| t.delete}
    assert_equal %w(talbott omelia).sort, Person.lookup_values(:family_key).sort

    @talbotts[-1].delete
    assert_equal %w(omelia).sort, Person.lookup_values(:family_key).sort

    @talbotts[0].index!
    @talbotts[0].index!
    assert_equal %w(talbott omelia).sort, Person.lookup_values(:family_key).sort
  end

  def test_index_destruction
    original_klass = Class.new do
      include Relix
      relix do
        primary_key :key
        multi :other
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
        obsolete{multi :other}
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
