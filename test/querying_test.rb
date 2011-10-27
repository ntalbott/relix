require 'test_helper'

class QueryingTest < RedixTest
  include FamilyFixture

  def test_missing_index
    model = Class.new do
      include Redix
      redix.primary_key :key
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
end