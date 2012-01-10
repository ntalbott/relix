require 'test_helper'
require 'support/redis_wrapper'

class PrimaryKeyIndexTest < RelixTest
  include FamilyFixture

  def setup
    create_families
  end

  def test_reindex
    @talbotts.each{|t| t.family_key = "talbot"; t.index!}
    assert_equal @talbotts.collect{|e| e.key}.sort, Person.lookup{|q| q[:family_key].eq("talbot")}.sort
    assert_equal [], Person.lookup{|q| q[:family_key].eq(@talbott_family.key)}
  end

  def test_deindex
    assert Person.lookup.include?(@nathaniel.key), "expected index to include Nathaniel's key"
    @nathaniel.delete
    assert !Person.lookup.include?(@nathaniel.key), "expected index not to include Nathaniel's key"
  end

  def test_lookup_all
    assert_equal [@talbott_family.key, @omelia_family.key].sort, Family.lookup.sort
  end

  def test_lookup_by_primary_key
    assert_equal [@talbott_family.key], Family.lookup{|q| q[:key].eq('talbott')}
    assert_equal [@omelia_family.key], Family.lookup{|q| q[:key].eq('omelia')}
  end

  def test_lookup_all_returns_in_insertion_order
    assert_equal @everyone.collect{|e| e.key}, Person.lookup
  end

  def test_primary_key_not_stored_in_current_values
    redis_hash = Person.relix.current_values_name('nathaniel')
    current_values = Relix.redis.hgetall(redis_hash)
    assert !current_values.keys.include?('key'), 'expected the current values hash not to contain a duplicate of the primary key'
  end

  def primary_key_only_class
    Class.new do
      include Relix
      relix.primary_key :key
      relix.redis = RedisWrapper.new(relix.redis)
      attr_accessor :key
      def initialize(key); @key = key; index!; end
    end
  end

  def test_current_values_hash_not_stored_when_only_primary_key
    klass = primary_key_only_class
    klass.relix.redis.before(:hmset) do
      raise "hmset should not be called"
    end
    record = klass.new("foo")
  end
end
