require 'test_helper'

class PrimaryKeyTest < RedixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_lookup_all
    assert_equal [@talbott_family.key, @omelia_family.key].sort, Family.lookup.sort
  end

  def test_lookup_by_primary_key
    assert_equal [@talbott_family.key], Family.lookup{|q| q[:primary_key].eq('talbott')}
    assert_equal [@omelia_family.key], Family.lookup{|q| q[:primary_key].eq('omelia')}
  end

  def test_lookup_all_returns_in_insertion_order
    assert_equal @everyone.collect{|e| e.key}, Person.lookup
  end
end