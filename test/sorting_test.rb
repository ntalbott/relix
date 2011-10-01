require 'test_helper'

class SortingTest < RedixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_sort_by_primary_key_by_default
    assert_equal @talbotts.collect{|e| e.key}, Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}
  end
end