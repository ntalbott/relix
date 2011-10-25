require 'test_helper'

class BasicIndexTest < RedixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_lookup
    assert_equal @talbotts.collect{|e| e.key}.sort, Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}.sort
    assert_equal [], Person.lookup{|q| q[:family_key].eq("bogus")}
  end

  def test_reindex
    @talbotts.each{|t| t.family_key = "talbot"; t.index!}
    assert_equal @talbotts.collect{|e| e.key}.sort, Person.lookup{|q| q[:family_key].eq("talbot")}.sort
    assert_equal [], Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}
  end
end