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

  def test_lt_query
    create_families
    assert_equal %w(kelly duff katie nathaniel madeline), Person.lookup { |q| q[:by_birthyear].lt(2000) }
  end

  def test_lte_query
    create_families
    assert_equal %w(kelly duff katie nathaniel madeline), Person.lookup { |q| q[:by_birthyear].lte(1998) }
  end

  def test_gt_query
    create_families
    assert_equal %w(elaine etan mackinley katherine logan), Person.lookup { |q| q[:by_birthyear].gt(2006) }
  end

  def test_gte_query
    create_families
    assert_equal %w(elaine etan mackinley katherine logan), Person.lookup { |q| q[:by_birthyear].gte(2007) }
  end

  def test_lt_gt_query
    create_families
    assert_equal %w(keagan reuben), Person.lookup { |q| q[:by_birthyear].gt(2000).lt(2004) }
  end

  def test_lte_gte_query
    create_families
    assert_equal %w(gavin keagan reuben luke), Person.lookup { |q| q[:by_birthyear].gte(2000).lte(2004) }
  end
end
