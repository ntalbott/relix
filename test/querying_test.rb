require 'test_helper'

class QueryingTest < RedixTest
  include FamilyFixture

  def test_missing_index
    model = Class.new do
      include Redix
      primary_key :key
    end
    assert_raise Redix::MissingIndexError do
      model.lookup{|q| q[:bogus].eq('something')}
    end
  end

  def test_missing_primary_key
    model = Class.new do
      include Redix
    end
    assert_raise Redix::MissingPrimaryKeyError do
      model.lookup
    end
  end

  def test_multiple_indexes
    create_families
    assert_equal [@william.key, @gabrielle.key], Person.lookup{|q| q[:birthyear].eq(2006)}
    assert_equal [@william.key], Person.lookup{|q| q[:family_key].eq("talbott")[:birthyear].eq(2006)}
  end
end