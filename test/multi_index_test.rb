require 'test_helper'

class MultiIndexTest < RedixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_lookup
    assert_equal @talbotts.collect{|e| e.key}.sort, Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}.sort
    assert_equal [], Person.lookup{|q| q[:family_key].eq("bogus")}
  end

  def test_offset_by_key
    assert_equal %w(reuben annemarie), Person.lookup{|q| q[:family_key].eq(@talbott_family.key, from: "nathaniel", limit: 2)}
  end

  def test_offset_by_missing_key
    assert_raise Redix::MissingIndexValueError do
      Person.lookup{|q| q[:family_key].eq(@talbott_family.key, from: "bogus", limit: 2)}
    end
  end

  def test_limit_of_zero
    assert_equal [], Person.lookup{|q| q[:family_key].eq(@talbott_family.key, limit: 0)}
  end
end