require 'test_helper'

class KeyingTest < RelixTest
  def setup
    @m = Class.new do
      def self.name; "TestModel"; end
      include Relix
      relix do
        primary_key :key
        unique :email
        multi :parent
      end
      attr_accessor :key, :email, :parent
      def initialize(k,e,p); @key,@email,@parent = k,e,p; index! end
    end
  end

  def test_legacy_keys
    @m.relix.keyer(Relix::Keyer::Legacy)

    assert_equal "TestModel:current_values:1", @m.relix.current_values_name("1")
    assert_equal "TestModel:name", @m.relix.key_prefix("name")

    assert_equal "Relix::PrimaryKeyIndex:TestModel:primary_key",
      @m.relix.primary_key_index.name

    assert_equal "Relix::UniqueIndex:TestModel:email",
      @m.relix.indexes['email'].name
    assert_equal "Relix::UniqueIndex:TestModel:email:hash",
      @m.relix.indexes['email'].hash_name
    assert_equal "Relix::UniqueIndex:TestModel:email:zset",
      @m.relix.indexes['email'].sorted_set_name

    assert_equal "Relix::MultiIndex:TestModel:parent:fred",
      @m.relix.indexes['parent'].key_for('fred')
    assert_equal "Relix::MultiIndex:TestModel:parent",
      @m.relix.indexes['parent'].name
  end

  def test_standard_keys
    @m.relix.keyer(Relix::Keyer::Standard)

    assert_equal "TestModel:values:1", @m.relix.current_values_name("1")

    assert_equal "TestModel:key:primary_key",
      @m.relix.primary_key_index.name

    assert_equal "TestModel:email:unique",
      @m.relix.indexes['email'].name
    assert_equal "TestModel:email:unique:lookup",
      @m.relix.indexes['email'].hash_name
    assert_equal "TestModel:email:unique:ordering",
      @m.relix.indexes['email'].sorted_set_name

    assert_equal "TestModel:parent:multi:fred",
      @m.relix.indexes['parent'].key_for('fred')
    assert_equal "TestModel:parent:multi",
      @m.relix.indexes['parent'].name
  end

  def test_compact_keys_with_string
    @m.relix.keyer(Relix::Keyer::Compact, abbrev: "TM")

    assert_equal "TM:v:1", @m.relix.current_values_name("1")

    assert_equal "TM:key:p",
      @m.relix.primary_key_index.name

    assert_equal "TM:email:u",
      @m.relix.indexes['email'].name
    assert_equal "TM:email:u:lookup",
      @m.relix.indexes['email'].hash_name
    assert_equal "TM:email:u:ordering",
      @m.relix.indexes['email'].sorted_set_name

    assert_equal "TM:parent:m:fred",
      @m.relix.indexes['parent'].key_for('fred')
    assert_equal "TM:parent:m",
      @m.relix.indexes['parent'].name
  end

  def test_compact_keys_with_proc
    @m.relix.keyer(Relix::Keyer::Compact, abbrev: proc do |model_name|
      model_name[0..2]
    end)

    assert_equal "Tes:v:1", @m.relix.current_values_name("1")

    assert_equal "Tes:key:p",
      @m.relix.primary_key_index.name

    assert_equal "Tes:email:u",
      @m.relix.indexes['email'].name
    assert_equal "Tes:email:u:lookup",
      @m.relix.indexes['email'].hash_name
    assert_equal "Tes:email:u:ordering",
      @m.relix.indexes['email'].sorted_set_name

    assert_equal "Tes:parent:m:fred",
      @m.relix.indexes['parent'].key_for('fred')
    assert_equal "Tes:parent:m",
      @m.relix.indexes['parent'].name
  end

  def test_key_migration
    @m.relix.keyer(Relix::Keyer::Legacy)
    @m.new(1, "bob@example.com", "fred")
    @m.new(2, "kate@example.com", "fred")

    @m.relix.keyer(Relix::Keyer::Migrator,
      from: Relix::Keyer::Legacy,
      to: Relix::Keyer::Compact)

    assert_equal %w(1), @m.lookup{|q| q[:email].eq("bob@example.com")}
    assert_equal %w(1 2), @m.lookup{|q| q[:parent].eq("fred")}
  end
end