require 'test_helper'

require 'date'

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

  def test_date_and_time_ordering
    klass = Class.new do
      include Redix
      redix do
        primary_key :key
        multi :stuff, order: :created_at
      end
      attr_accessor :key, :stuff, :created_at
    end
    object = klass.new
    object.key = 'a'
    object.stuff = 'a'
    object.created_at = Time.now
    assert_nothing_raised do
      object.index!
    end

    object.stuff = 'b'
    object.created_at = Date.today
    assert_nothing_raised do
      object.index!
    end

    object.stuff = 'c'
    object.created_at = DateTime.now
    assert_nothing_raised do
      object.index!
    end
  end

  def test_bad_ordering_value
    klass = Class.new do
      include Redix
      redix do
        primary_key :key
        multi :stuff, order: :created_at
      end
      attr_accessor :key, :stuff, :created_at
    end
    object = klass.new
    object.key = 'a'
    object.stuff = 'a'
    object.created_at = Object.new
    assert_raise Redix::UnorderableValueError do
      object.index!
    end
  end
end