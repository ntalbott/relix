require 'test_helper'

class OrderingTest < RedixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_ordered_by_specified_attribute
    assert_equal @talbotts.sort_by{|e| [e.birthyear, e.key]}.collect{|e| e.key},
      Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}
  end

  def test_sort_by_numeric_key
    assert_equal @everyone.sort_by{|e| [e.birthyear, e.key]}.collect{|e| e.key},
      Person.lookup{|q| q[:by_birthyear].all}
  end

  def test_limit
    assert_equal @everyone.sort_by{|e| [e.birthyear, e.key]}.collect{|e| e.key}[0..4],
      Person.lookup{|q| q[:by_birthyear].all(limit: 5)}
  end

  def test_offset
    assert_equal @everyone.sort_by{|e| [e.birthyear, e.key]}.collect{|e| e.key}[5..-1],
      Person.lookup{|q| q[:by_birthyear].all(offset: 5)}
  end
end