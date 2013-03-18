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
end
