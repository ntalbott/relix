require 'test_helper'

require 'date'

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

  def test_eq_query
    assert_equal %w(gabrielle william), Person.lookup { |q| q[:birthyear].eq(2006) }
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

  def klass_with_ordered_date_index
    Class.new do
      include Relix
      relix.primary_key :key
      relix.ordered :date
      attr_accessor :key, :date
      def initialize(key, date); @key, @date = key, date; index!; end
    end
  end

  def test_lt_date_value
    klass = klass_with_ordered_date_index
    before_record = klass.new("before", Date.new(2011, 8, 3))
    after_record = klass.new("after", Date.new(2011, 9, 3))
    assert_equal %w(before), klass.lookup { |q| q[:date].lt(Date.new(2011, 8, 15)) }
  end

  def test_index_destruction
    original_klass = Class.new do
      include Relix
      relix do
        primary_key :key
        ordered :other
      end
      attr_accessor :key, :other

      def self.name; "MyKlass"; end
    end

    object1 = original_klass.new
    object1.key = 1
    object1.other = 1
    object1.index!

    object2 = original_klass.new
    object2.key = 2
    object2.other = 2
    object2.index!

    klass = Class.new do
      include Relix
      relix do
        primary_key :key
        obsolete{ordered :other}
      end
      attr_accessor :key, :other

      def self.name; "MyKlass"; end
    end

    klass.relix.destroy_index(:other)

    assert_equal 2, klass.lookup.count
    assert_equal [], Relix.redis.hgetall(klass.relix.current_values_name("1")).keys
    assert_equal [], Relix.redis.hgetall(klass.relix.current_values_name("2")).keys

    assert_equal 0, Relix.redis.keys("*other*").size, Relix.redis.keys("*other*")
  end
end
