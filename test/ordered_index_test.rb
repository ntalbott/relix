require 'test_helper'

class OrderedIndexTest < RelixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_invalid_order_raises_error
    assert_nothing_raised do
      Person.lookup { |q| q[:birthyear].order(:asc) }
    end

    assert_nothing_raised do
      Person.lookup { |q| q[:birthyear].order(:desc) }
    end

    assert_raise Relix::InvalidQueryOption do
      Person.lookup { |q| q[:birthyear].order(:boom) }
    end
  end

  def test_lt_query
    assert_equal %w(kelly duff katie nathaniel madeline), Person.lookup { |q| q[:birthyear].lt(2000) }
    assert_equal %w(kelly duff katie nathaniel madeline).reverse, Person.lookup { |q| q[:birthyear].lt(2000).order(:desc) }
  end

  def test_lte_query
    assert_equal %w(kelly duff katie nathaniel madeline), Person.lookup { |q| q[:birthyear].lte(1998) }
    assert_equal %w(kelly duff katie nathaniel madeline).reverse, Person.lookup { |q| q[:birthyear].lte(1998).order(:desc) }
  end

  def test_gt_query
    assert_equal %w(elaine etan mackinley katherine logan), Person.lookup { |q| q[:birthyear].gt(2006).order(:asc) }
    assert_equal %w(elaine etan mackinley katherine logan).reverse, Person.lookup { |q| q[:birthyear].gt(2006).order(:desc) }
  end

  def test_gte_query
    assert_equal %w(elaine etan mackinley katherine logan), Person.lookup { |q| q[:birthyear].gte(2007) }
    assert_equal %w(elaine etan mackinley katherine logan).reverse, Person.lookup { |q| q[:birthyear].gte(2007).order(:desc) }
  end

  def test_lt_gt_query
    assert_equal %w(keagan reuben), Person.lookup { |q| q[:birthyear].gt(2000).lt(2004) }
    assert_equal %w(keagan reuben).reverse, Person.lookup { |q| q[:birthyear].gt(2000).lt(2004).order(:desc) }
  end

  def test_lte_gte_query
    assert_equal %w(gavin keagan reuben luke), Person.lookup { |q| q[:birthyear].gte(2000).lte(2004) }
  end

  def test_offset_limited_ranged_queries
    assert_equal %w(keagan reuben), Person.lookup { |q| q[:birthyear].gt(1978).offset(3).limit(2) }
    assert_equal %w(elaine william gabrielle), Person.lookup { |q| q[:birthyear].lt(2010).offset(2).limit(3).order(:desc) }
    assert_equal %w(gavin keagan), Person.lookup { |q| q[:birthyear].lte(2011).gte(1998).offset(1).limit(2) }
    assert_equal %w(gavin keagan), Person.lookup { |q| q[:birthyear].lte(2011).offset(1).limit(2).gte(1998) }
  end

  def test_offset_limited_gt_query
    assert_equal %w(keagan reuben), Person.lookup { |q| q[:birthyear].gt(1978).offset(3).limit(2) }
  end

  def test_deindex
    assert Person.lookup{ |q| q[:birthyear] }.include?(@nathaniel.key), "expected to include Nathaniel's key"
    @nathaniel.delete
    assert !Person.lookup{|q| q[:birthyear] }.include?(@nathaniel.key), "expected not to include Nathaniel's key"
  end

  def test_reindex
    assert_equal %w(keagan reuben), Person.lookup { |q| q[:birthyear].gt(2000).lt(2004) }
    @nathaniel.birthyear = 2002
    @nathaniel.index!
    assert_equal %w(keagan nathaniel reuben), Person.lookup { |q| q[:birthyear].gt(2000).lt(2004) }
  end
end
