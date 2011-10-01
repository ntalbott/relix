require 'test_helper'

class BasicIndexTest < RedixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_lookup
    assert_equal @talbotts.collect{|e| e.key}.sort, Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}.sort
  end
end