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
    assert_equal %w(kelly duff katie nathaniel madeline).reverse, Person.lookup { |q| q[:by_birthyear].lt(2000).order(:desc) }
  end

  def test_lte_query
    create_families
    assert_equal %w(kelly duff katie nathaniel madeline), Person.lookup { |q| q[:by_birthyear].lte(1998) }
    assert_equal %w(kelly duff katie nathaniel madeline).reverse, Person.lookup { |q| q[:by_birthyear].lte(1998).order(:desc) }
  end

  def test_gt_query
    create_families
    assert_equal %w(elaine etan mackinley katherine logan), Person.lookup { |q| q[:by_birthyear].gt(2006).order(:asc) }
    assert_equal %w(elaine etan mackinley katherine logan).reverse, Person.lookup { |q| q[:by_birthyear].gt(2006).order(:desc) }
  end

  def test_gte_query
    create_families
    assert_equal %w(elaine etan mackinley katherine logan), Person.lookup { |q| q[:by_birthyear].gte(2007) }
    assert_equal %w(elaine etan mackinley katherine logan).reverse, Person.lookup { |q| q[:by_birthyear].gte(2007).order(:desc) }
  end

  def test_lt_gt_query
    create_families
    assert_equal %w(keagan reuben), Person.lookup { |q| q[:by_birthyear].gt(2000).lt(2004) }
    assert_equal %w(keagan reuben).reverse, Person.lookup { |q| q[:by_birthyear].gt(2000).lt(2004).order(:desc) }
  end

  def test_lte_gte_query
    create_families
    assert_equal %w(gavin keagan reuben luke), Person.lookup { |q| q[:by_birthyear].gte(2000).lte(2004) }
  end

  def test_offset_limited_ranged_queries
    create_families
    assert_equal %w(keagan reuben), Person.lookup { |q| q[:by_birthyear].gt(1978, offset: 3, limit: 2) }
    assert_equal %w(elaine william gabrielle), Person.lookup { |q| q[:by_birthyear].lt(2010, offset: 2, limit: 3).order(:desc) }
    assert_equal %w(gavin keagan), Person.lookup { |q| q[:by_birthyear].lte(2011).gte(1998, offset: 1, limit: 2) }
    assert_equal %w(gavin keagan), Person.lookup { |q| q[:by_birthyear].lte(2011, offset: 1, limit: 2).gte(1998) }
  end

  def test_offset_limited_gt_query
    create_families
    assert_equal %w(keagan reuben), Person.lookup { |q| q[:by_birthyear].gt(1978, offset: 3, limit: 2) }
  end
end
