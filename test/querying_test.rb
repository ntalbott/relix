require 'test_helper'

class QueryingTest < RelixTest
  include FamilyFixture

  def test_missing_index
    model = Class.new do
      include Relix
      relix.primary_key :key
    end
    assert_raise Relix::MissingIndexError do
      model.lookup{|q| q[:bogus].eq('something')}
    end
  end

  def test_missing_primary_key
    model = Class.new do
      include Relix
    end
    assert_raise Relix::MissingPrimaryKeyError do
      model.lookup
    end
  end
end